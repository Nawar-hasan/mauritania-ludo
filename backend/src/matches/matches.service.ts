import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { randomInt } from 'node:crypto';
import { InventorySource, LedgerDirection, MatchEventType, MatchMode, MatchPlayerStatus, MatchStatus, MatchmakingStatus, NotificationType, PlayerColor, Prisma, TransactionStatus, TransactionType, WalletType } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { RedisService } from '../redis/redis.service.js';
import { CreateMatchDto } from './dto/create-match.dto.js';
import { MatchmakingDto } from './dto/matchmaking.dto.js';
import { MoveDto } from './dto/move.dto.js';
import { GameState, EngineRules } from './game-engine.types.js';
import { LudoEngine } from './ludo-engine.js';

@Injectable()
export class MatchesService {
  constructor(private readonly prisma: PrismaService, private readonly redis: RedisService) {}

  private isWaitingStatus(status: MatchStatus): boolean {
    return status === MatchStatus.WAITING || status === MatchStatus.READY;
  }

  private isEliminatedStatus(status: MatchPlayerStatus): boolean {
    return status === MatchPlayerStatus.FORFEITED || status === MatchPlayerStatus.TIMED_OUT;
  }

  async listForUser(userId: string, cursor?: string) {
    const rows = await this.prisma.match.findMany({
      where: { players: { some: { userId } } },
      include: {
        players: { include: { user: { select: { username: true, profile: true } } }, orderBy: { seat: 'asc' } },
        ruleSet: true,
      },
      orderBy: { createdAt: 'desc' },
      take: 31,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
    });
    return { items: rows.slice(0, 30), nextCursor: rows.length > 30 ? rows[29].id : null };
  }

  async previewByCode(code: string, userId: string) {
    const match = await this.prisma.match.findUnique({
      where: { publicCode: code },
      include: {
        ruleSet: true,
        players: { include: { user: { select: { username: true, profile: true } } }, orderBy: { seat: 'asc' } },
      },
    });
    if (!match) throw new NotFoundException('Room not found');
    return {
      id: match.id,
      publicCode: match.publicCode,
      mode: match.mode,
      status: match.status,
      maxPlayers: match.maxPlayers,
      stakeAmount: match.stakeAmount,
      currency: match.currency,
      ruleSet: match.ruleSet,
      players: match.players,
      alreadyJoined: match.players.some((player) => player.userId === userId),
    };
  }

  async joinByCode(code: string, userId: string) {
    const match = await this.prisma.match.findUnique({ where: { publicCode: code } });
    if (!match) throw new NotFoundException('Room not found');
    return this.join(match.id, userId);
  }

  async getTicket(id: string, userId: string) {
    const ticket = await this.prisma.matchmakingTicket.findFirst({ where: { id, userId } });
    if (!ticket) throw new NotFoundException('Matchmaking ticket not found');
    return ticket;
  }

  async create(userId: string, dto: CreateMatchDto) {
    await this.ensureMatchesEnabled();
    const rules = await this.prisma.gameRuleSet.findUnique({ where: { code: dto.ruleCode } });
    if (!rules?.enabled) throw new BadRequestException('Rule set unavailable');
    const stake = dto.mode === MatchMode.WAGER || dto.mode === MatchMode.PRIVATE ? Number(dto.stakeAmount ?? 0) : 0;
    if (dto.mode === MatchMode.WAGER && stake <= 0) throw new BadRequestException('A wager match requires a positive stake');
    if (stake > 0) { await this.validateStake(stake); await this.ensureStakeAvailable(userId, stake); }
    const fee = await this.settingNumber('platform_fee_rate', 0.05);
    return this.prisma.$transaction(async (tx) => {
      const match = await tx.match.create({ data: {
        publicCode: await this.uniqueCode(), mode: dto.mode, maxPlayers: dto.maxPlayers, stakeAmount: stake,
        currency: dto.currency ?? 'MRU', platformFeeRate: fee, ruleSetId: rules.id,
        players: { create: { userId, seat: 0, color: PlayerColor.GREEN, status: MatchPlayerStatus.JOINED } },
        events: { create: { sequence: 1, type: MatchEventType.MATCH_CREATED, actorUserId: userId, payload: { mode: dto.mode, maxPlayers: dto.maxPlayers, stake } } },
      }, include: { players: true, ruleSet: true } });
      if (stake > 0) await this.reserveStake(tx, userId, stake, match.id);
      return match;
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
  }
  async join(matchId: string, userId: string) {
    await this.ensureMatchesEnabled();
    return this.redis.withLock(`match:${matchId}`, 5000, async () => {
      const match = await this.full(matchId); if (match.status !== MatchStatus.WAITING) throw new BadRequestException('Match is not joinable');
      if (match.players.some((p) => p.userId === userId)) return match;
      if (match.players.length >= match.maxPlayers) throw new BadRequestException('Match is full');
      const colors = match.maxPlayers === 2
        ? [PlayerColor.GREEN, PlayerColor.RED]
        : [PlayerColor.GREEN, PlayerColor.YELLOW, PlayerColor.BLUE, PlayerColor.RED];
      const usedSeats = new Set(match.players.map((player) => player.seat));
      const seat = Array.from({ length: match.maxPlayers }, (_, index) => index).find((index) => !usedSeats.has(index));
      if (seat == null) throw new BadRequestException('Match is full');
      const sequence = await this.nextSequence(matchId);
      await this.prisma.$transaction(async (tx) => {
        if (Number(match.stakeAmount) > 0) await this.reserveStake(tx, userId, Number(match.stakeAmount), match.id);
        await tx.matchPlayer.create({ data: { matchId, userId, seat, color: colors[seat]!, status: MatchPlayerStatus.JOINED } });
        await tx.matchEvent.create({ data: { matchId, actorUserId: userId, sequence, type: MatchEventType.PLAYER_JOINED } });
        if (match.players.length + 1 === match.maxPlayers) await tx.match.update({ where: { id: matchId }, data: { status: MatchStatus.READY } });
      }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
      return this.full(matchId);
    });
  }
  async start(matchId: string, userId: string) {
    return this.redis.withLock(`match:${matchId}`, 5000, async () => {
      const match = await this.full(matchId); if (match.players[0]?.userId !== userId) throw new ForbiddenException('Only the host can start');
      if (!this.isWaitingStatus(match.status) || match.players.length !== match.maxPlayers) throw new BadRequestException('All seats must be filled');
      const sequence = await this.nextSequence(matchId);
      const state = LudoEngine.create(match.players.sort((a,b)=>a.seat-b.seat).map((p) => p.userId), this.rules(match.ruleSet));
      await this.prisma.$transaction([
        this.prisma.match.update({ where: { id: matchId }, data: { status: MatchStatus.ACTIVE, startedAt: new Date(), currentState: state as any, stateVersion: state.version, nextActionAt: new Date(state.turnDeadline) } }),
        this.prisma.matchPlayer.updateMany({ where: { matchId }, data: { status: MatchPlayerStatus.ACTIVE } }),
        this.prisma.matchEvent.create({ data: { matchId, actorUserId: userId, sequence, type: MatchEventType.MATCH_STARTED, payload: state as any } }),
      ]);
      return this.full(matchId);
    });
  }
  async roll(matchId: string, userId: string) {
    return this.mutate(matchId, userId, (state, rules) => ({ state: LudoEngine.roll(state, userId, randomInt(1, 7), rules), type: MatchEventType.DICE_ROLLED }));
  }
  async move(matchId: string, userId: string, dto: MoveDto) {
    return this.mutate(matchId, userId, (state, rules) => {
      if (state.version !== dto.expectedVersion) throw new BadRequestException('Stale game state');
      const result = LudoEngine.move(state, userId, dto.pieceId, rules);
      return { state: result.state, type: MatchEventType.PIECE_MOVED, payload: { pieceId: dto.pieceId, captured: result.captured, finishedPiece: result.finishedPiece } };
    });
  }
  async forfeit(matchId: string, userId: string) {
    return this.redis.withLock(`match:${matchId}`, 5000, async () => {
      const match = await this.full(matchId);
      return this.eliminatePlayer(match, userId, MatchPlayerStatus.FORFEITED, MatchEventType.PLAYER_FORFEITED);
    });
  }
  async cancelMatch(matchId: string, userId: string) {
    return this.redis.withLock(`match:${matchId}`, 5000, async () => {
      const match = await this.full(matchId);
      if (match.players[0]?.userId !== userId) throw new ForbiddenException('Only the host can cancel the room');
      if (!this.isWaitingStatus(match.status)) throw new BadRequestException('Only a waiting room can be cancelled');
      const stake = Number(match.stakeAmount);
      return this.prisma.$transaction(async (tx) => {
        const sequence = await this.nextSequence(matchId, tx);
        await tx.match.update({
          where: { id: matchId },
          data: {
            status: stake > 0 ? MatchStatus.REFUNDED : MatchStatus.CANCELLED,
            cancelledAt: new Date(),
            nextActionAt: null,
          },
        });
        await tx.matchPlayer.updateMany({
          where: { matchId },
          data: { status: MatchPlayerStatus.FINISHED, finishedAt: new Date() },
        });
        await tx.matchEvent.create({
          data: {
            matchId,
            actorUserId: userId,
            sequence,
            type: MatchEventType.MATCH_CANCELLED,
            payload: { refunded: stake > 0 },
          },
        });
        if (stake > 0) {
          for (const player of match.players) await this.refundStake(tx, player.userId, stake, match.id, 'Room cancelled before start');
        }
        await tx.notification.createMany({ data: match.players.map((player: any) => ({
          userId: player.userId,
          type: NotificationType.MATCH,
          title: stake > 0 ? 'Room cancelled and wager refunded' : 'Room cancelled',
          body: `Room ${match.publicCode} was cancelled before the match started.`,
          data: { matchId: match.id },
        })) });
        return tx.match.findUnique({
          where: { id: matchId },
          include: { players: { include: { user: { select: { username: true, profile: true } } }, orderBy: { seat: 'asc' } }, ruleSet: true, events: { orderBy: { sequence: 'asc' } } },
        });
      }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    });
  }

  async leaveWaitingRoom(matchId: string, userId: string) {
    return this.redis.withLock(`match:${matchId}`, 5000, async () => {
      const match = await this.full(matchId);
      if (!this.isWaitingStatus(match.status)) throw new BadRequestException('The match has already started');
      const player = match.players.find((candidate) => candidate.userId === userId);
      if (!player) throw new ForbiddenException();
      if (match.players[0]?.userId === userId) return this.cancelMatchUnlocked(match, userId);
      const stake = Number(match.stakeAmount);
      const colors = match.maxPlayers === 2
        ? [PlayerColor.GREEN, PlayerColor.RED]
        : [PlayerColor.GREEN, PlayerColor.YELLOW, PlayerColor.BLUE, PlayerColor.RED];
      return this.prisma.$transaction(async (tx) => {
        const sequence = await this.nextSequence(matchId, tx);
        if (stake > 0) await this.refundStake(tx, userId, stake, match.id, 'Player left before start');
        await tx.matchPlayer.delete({ where: { id: player.id } });
        await tx.matchPlayer.updateMany({ where: { matchId }, data: { seat: { increment: 100 } } });
        const remaining = match.players.filter((candidate) => candidate.userId !== userId).sort((a, b) => a.seat - b.seat);
        for (let index = 0; index < remaining.length; index++) {
          await tx.matchPlayer.update({ where: { id: remaining[index].id }, data: { seat: index, color: colors[index]! } });
        }
        await tx.match.update({ where: { id: matchId }, data: { status: MatchStatus.WAITING } });
        await tx.matchEvent.create({
          data: { matchId, actorUserId: userId, sequence, type: MatchEventType.PLAYER_FORFEITED, payload: { beforeStart: true, refunded: stake > 0 } },
        });
        if (remaining.length > 0) await tx.notification.create({ data: {
          userId: remaining[0].userId,
          type: NotificationType.MATCH,
          title: 'Player left the waiting room',
          body: `A player left room ${match.publicCode} before the match started.`,
          data: { matchId },
        } });
        return { left: true, refunded: stake > 0 };
      }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    });
  }
  async getForUser(id: string, userId: string) { const match = await this.full(id); if (!match.players.some((p) => p.userId === userId)) throw new ForbiddenException(); return match; }
  async matchmake(userId: string, dto: MatchmakingDto) {
    await this.ensureMatchesEnabled();
    const existing = await this.prisma.matchmakingTicket.findFirst({
      where: { userId, status: MatchmakingStatus.SEARCHING, expiresAt: { gt: new Date() } },
    });
    if (existing) return existing;

    const stake = dto.mode === MatchMode.WAGER ? dto.stakeAmount ?? 0 : 0;
    if (dto.mode === MatchMode.WAGER && stake <= 0) throw new BadRequestException('A wager match requires a positive stake');
    if (stake > 0) { await this.validateStake(stake); await this.ensureStakeAvailable(userId, stake); }
    const ticket = await this.prisma.matchmakingTicket.create({
      data: {
        userId,
        mode: dto.mode,
        maxPlayers: dto.maxPlayers,
        stakeAmount: stake,
        ruleCode: dto.ruleCode,
        expiresAt: new Date(Date.now() + 120_000),
      },
    });
    const peers = await this.prisma.matchmakingTicket.findMany({
      where: {
        id: { not: ticket.id },
        status: MatchmakingStatus.SEARCHING,
        mode: dto.mode,
        maxPlayers: dto.maxPlayers,
        stakeAmount: stake,
        ruleCode: dto.ruleCode,
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: 'asc' },
      take: dto.maxPlayers - 1,
    });
    if (peers.length !== dto.maxPlayers - 1) return ticket;

    const rules = await this.prisma.gameRuleSet.findUnique({ where: { code: dto.ruleCode } });
    if (!rules?.enabled) throw new BadRequestException('Rule set unavailable');
    const fee = await this.settingNumber('platform_fee_rate', 0.05);
    const participants = [userId, ...peers.map((peer) => peer.userId)];
    const ticketIds = [ticket.id, ...peers.map((peer) => peer.id)];
    const colors = dto.maxPlayers === 2
      ? [PlayerColor.GREEN, PlayerColor.RED]
      : [PlayerColor.GREEN, PlayerColor.YELLOW, PlayerColor.BLUE, PlayerColor.RED];
    const publicCode = await this.uniqueCode();

    return this.prisma.$transaction(async (tx) => {
      const claimed = await tx.matchmakingTicket.updateMany({
        where: { id: { in: ticketIds }, status: MatchmakingStatus.SEARCHING, expiresAt: { gt: new Date() } },
        data: { status: MatchmakingStatus.MATCHED },
      });
      if (claimed.count !== dto.maxPlayers) throw new BadRequestException('Matchmaking group is no longer available');

      const match = await tx.match.create({
        data: {
          publicCode,
          mode: dto.mode,
          status: MatchStatus.READY,
          maxPlayers: dto.maxPlayers,
          stakeAmount: stake,
          currency: 'MRU',
          platformFeeRate: fee,
          ruleSetId: rules.id,
          players: {
            create: participants.map((participantId, index) => ({
              userId: participantId,
              seat: index,
              color: colors[index]!,
              status: MatchPlayerStatus.JOINED,
            })),
          },
          events: {
            create: {
              sequence: 1,
              type: MatchEventType.MATCH_CREATED,
              actorUserId: userId,
              payload: { source: 'MATCHMAKING', mode: dto.mode, maxPlayers: dto.maxPlayers, stake },
            },
          },
        },
        include: { players: true, ruleSet: true },
      });

      if (stake > 0) {
        for (const participantId of participants) {
          await this.reserveStake(tx, participantId, stake, match.id);
        }
      }
      await tx.matchmakingTicket.updateMany({ where: { id: { in: ticketIds } }, data: { matchId: match.id } });
      return { ticketId: ticket.id, matchId: match.id, status: MatchmakingStatus.MATCHED };
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
  }
  cancelTicket(id: string, userId: string) { return this.prisma.matchmakingTicket.updateMany({ where: { id, userId, status: MatchmakingStatus.SEARCHING }, data: { status: MatchmakingStatus.CANCELLED } }); }
  async processTimeout(matchId: string) {
    return this.redis.withLock(`match:${matchId}`, 5000, async () => {
      const match = await this.full(matchId);
      if (match.status !== MatchStatus.ACTIVE || !match.currentState) return;
      const state = match.currentState as unknown as GameState;
      const current = state.players[state.turnIndex];
      const record = match.players.find((player) => player.userId === current.userId);
      if (!record || this.isEliminatedStatus(record.status)) return;

      const inactiveTurns = record.inactiveTurns + 1;
      if (inactiveTurns >= match.ruleSet.maxInactiveTurns) {
        await this.prisma.matchPlayer.update({
          where: { id: record.id },
          data: { inactiveTurns: { increment: 1 } },
        });
        return this.eliminatePlayer(match, current.userId, MatchPlayerStatus.TIMED_OUT, MatchEventType.TURN_TIMED_OUT);
      }

      await this.prisma.matchPlayer.update({
        where: { id: record.id },
        data: { inactiveTurns: { increment: 1 } },
      });
      const next = LudoEngine.autoAction(state, this.rules(match.ruleSet), randomInt(1, 7));
      await this.persistState(match, current.userId, next, MatchEventType.TURN_TIMED_OUT, { automatic: true, inactiveTurns });
    });
  }

  private async eliminatePlayer(
    match: any,
    userId: string,
    status: MatchPlayerStatus,
    eventType: MatchEventType,
  ) {
    const player = match.players.find((candidate: any) => candidate.userId === userId);
    if (!player) throw new ForbiddenException();
    if (this.isEliminatedStatus(player.status)) return this.full(match.id);

    await this.prisma.matchPlayer.update({
      where: { id: player.id },
      data: { status, finishedAt: new Date() },
    });

    const active = match.players.filter((candidate: any) =>
      candidate.userId !== userId &&
      !this.isEliminatedStatus(candidate.status),
    );

    if (match.status === MatchStatus.ACTIVE && match.currentState) {
      const state = structuredClone(match.currentState as unknown as GameState);
      const index = state.players.findIndex((candidate) => candidate.userId === userId);
      if (index >= 0) {
        state.players[index].finished = true;
        state.version += 1;
        state.lastAction = status === MatchPlayerStatus.TIMED_OUT ? 'PLAYER_TIMED_OUT' : 'PLAYER_FORFEITED';
        state.dice = null;
        state.legalPieceIds = [];
        state.moveDeadline = null;
        if (active.length > 1 && state.turnIndex === index) {
          let next = index;
          do { next = (next + 1) % state.players.length; } while (state.players[next].finished && next !== index);
          state.turnIndex = next;
        }
        if (active.length > 1) {
          state.phase = 'ROLL';
          state.turnDeadline = new Date(Date.now() + match.ruleSet.rollSeconds * 1000).toISOString();
        } else if (active.length === 1) {
          state.phase = 'FINISHED';
          if (!state.winnerOrder.includes(active[0].userId)) state.winnerOrder.push(active[0].userId);
        }
        await this.persistState(match, userId, state, eventType, { userId, status });
      }
    } else {
      const sequence = await this.nextSequence(match.id);
      await this.prisma.matchEvent.create({
        data: { matchId: match.id, actorUserId: userId, sequence, type: eventType, payload: { userId, status } },
      });
    }

    if (active.length === 1) await this.complete(await this.full(match.id), active[0].userId);
    return this.full(match.id);
  }
  private async mutate(matchId: string, userId: string, action: (state: GameState, rules: EngineRules) => { state: GameState; type: MatchEventType; payload?: any }) {
    return this.redis.withLock(`match:${matchId}`, 5000, async () => {
      const match = await this.full(matchId); if (match.status !== MatchStatus.ACTIVE || !match.currentState) throw new BadRequestException('Match is not active');
      const result = action(match.currentState as unknown as GameState, this.rules(match.ruleSet));
      await this.persistState(match, userId, result.state, result.type, result.payload);
      await this.prisma.matchPlayer.updateMany({ where: { matchId, userId }, data: { inactiveTurns: 0 } });
      if (result.state.phase === 'FINISHED') await this.complete(match, result.state.winnerOrder[0]);
      return this.full(matchId);
    });
  }
  private async persistState(match: any, actorUserId: string, state: GameState, type: MatchEventType, payload?: any) {
    const sequence = await this.nextSequence(match.id);
    const deadline = state.phase === 'FINISHED'
      ? null
      : new Date(state.phase === 'MOVE' ? state.moveDeadline! : state.turnDeadline);
    await this.prisma.$transaction([
      this.prisma.match.update({ where: { id: match.id }, data: { currentState: state as any, stateVersion: state.version, nextActionAt: deadline } }),
      this.prisma.matchEvent.create({ data: { matchId: match.id, actorUserId, sequence, type, payload: { stateVersion: state.version, ...(payload ?? {}) } } }),
    ]);
  }
  private async complete(match: any, winnerUserId: string) {
    if (match.status === MatchStatus.COMPLETED) return;
    const stake = Number(match.stakeAmount);
    await this.prisma.$transaction(async (tx) => {
      const fresh = await tx.match.findUnique({ where: { id: match.id } });
      if (!fresh || fresh.status === MatchStatus.COMPLETED) return;
      const sequence = await this.nextSequence(match.id, tx);
      await tx.match.update({ where: { id: match.id }, data: { status: MatchStatus.COMPLETED, winnerUserId, completedAt: new Date(), nextActionAt: null } });
      await tx.matchEvent.create({ data: { matchId: match.id, actorUserId: winnerUserId, sequence, type: MatchEventType.MATCH_COMPLETED, payload: { winnerUserId } } });
      for (const player of match.players) {
        await tx.matchPlayer.update({
          where: { id: player.id },
          data: {
            status: this.isEliminatedStatus(player.status)
              ? player.status
              : MatchPlayerStatus.FINISHED,
            finishPosition: player.userId === winnerUserId ? 1 : player.finishPosition,
            finishedAt: player.finishedAt ?? new Date(),
          },
        });
        const profile = await tx.userProfile.findUnique({ where: { userId: player.userId } });
        if (profile) {
          const xpGain = player.userId === winnerUserId ? 100 : 20;
          const nextXp = profile.xp + xpGain;
          const nextLevel = await tx.levelDefinition.findFirst({
            where: { enabled: true, xpRequired: { lte: nextXp } },
            orderBy: { level: 'desc' },
          });
          const resolvedLevel = Math.max(profile.level, nextLevel?.level ?? profile.level);
          await tx.userProfile.update({
            where: { userId: player.userId },
            data: {
              matches: { increment: 1 },
              xp: { increment: xpGain },
              level: resolvedLevel,
              ...(player.userId === winnerUserId ? { wins: { increment: 1 } } : { losses: { increment: 1 } }),
            },
          });
          if (nextLevel && resolvedLevel > profile.level) {
            const crossedLevels = await tx.levelDefinition.findMany({
              where: { enabled: true, level: { gt: profile.level, lte: resolvedLevel } },
              orderBy: { level: 'asc' },
            });
            for (const definition of crossedLevels) {
              await this.grantProgressionRewards(tx, player.userId, 'LEVEL', String(definition.level), `Level ${definition.level}`, definition.rewards);
            }
            const crossedStages = await tx.stageDefinition.findMany({
              where: { enabled: true, minLevel: { gt: profile.level, lte: resolvedLevel } },
              orderBy: [{ minLevel: 'asc' }, { sortOrder: 'asc' }],
            });
            for (const stage of crossedStages) {
              await this.grantProgressionRewards(tx, player.userId, 'STAGE', stage.id, `Stage ${stage.code}`, stage.rewards);
            }
          }
        }
      }
      await tx.notification.createMany({ data: match.players.map((player: any) => ({
        userId: player.userId,
        type: NotificationType.MATCH,
        title: player.userId === winnerUserId ? 'You won the match' : 'Match completed',
        body: player.userId === winnerUserId ? `You won match ${match.publicCode}.` : `Match ${match.publicCode} has ended.`,
        data: { matchId: match.id, winnerUserId },
      })) });
      if (stake <= 0) return;
      const pool = stake * match.players.length;
      const fee = pool * Number(match.platformFeeRate);
      const prize = pool - fee;
      for (const player of match.players) {
        const locked = await tx.walletAccount.findUnique({ where: { userId_type_currency: { userId: player.userId, type: WalletType.LOCKED, currency: match.currency } } });
        if (!locked || locked.balance.lessThan(stake)) throw new BadRequestException('Locked wager balance is inconsistent');
        const after = locked.balance.sub(stake);
        const transaction = await tx.financialTransaction.create({ data: { userId: player.userId, type: TransactionType.WAGER_RELEASE, status: TransactionStatus.COMPLETED, amount: stake, currency: match.currency, description: 'Wager settled', processedAt: new Date(), metadata: { matchId: match.id } } });
        await tx.walletAccount.update({ where: { id: locked.id }, data: { balance: after, version: { increment: 1 } } });
        await tx.ledgerEntry.create({ data: { userId: player.userId, accountId: locked.id, transactionId: transaction.id, direction: LedgerDirection.DEBIT, amount: stake, balanceBefore: locked.balance, balanceAfter: after, referenceType: 'MATCH', referenceId: match.id, description: 'Wager settled' } });
      }
      const cash = await tx.walletAccount.findUnique({ where: { userId_type_currency: { userId: winnerUserId, type: WalletType.CASH, currency: match.currency } } });
      if (!cash) throw new BadRequestException('Winner cash wallet is unavailable');
      const cashAfter = cash.balance.add(prize);
      const prizeTransaction = await tx.financialTransaction.create({ data: { userId: winnerUserId, type: TransactionType.MATCH_PRIZE, status: TransactionStatus.COMPLETED, amount: prize, fee, currency: match.currency, description: 'Match prize', processedAt: new Date(), metadata: { matchId: match.id } } });
      await tx.walletAccount.update({ where: { id: cash.id }, data: { balance: cashAfter, version: { increment: 1 } } });
      await tx.ledgerEntry.create({ data: { userId: winnerUserId, accountId: cash.id, transactionId: prizeTransaction.id, direction: LedgerDirection.CREDIT, amount: prize, balanceBefore: cash.balance, balanceAfter: cashAfter, referenceType: 'MATCH', referenceId: match.id, description: 'Match prize' } });
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
  }
  private async grantProgressionRewards(
    tx: Prisma.TransactionClient,
    userId: string,
    referenceType: 'LEVEL' | 'STAGE',
    referenceId: string,
    label: string,
    rawRewards: unknown,
  ) {
    const rewards = (rawRewards && typeof rawRewards === 'object' ? rawRewards : {}) as Record<string, unknown>;
    for (const [walletType, key] of [[WalletType.COINS, 'coins'], [WalletType.GEMS, 'gems'], [WalletType.BONUS, 'bonus']] as const) {
      const amount = Number(rewards[key] ?? 0);
      if (!Number.isFinite(amount) || amount <= 0) continue;
      const account = await tx.walletAccount.findUnique({ where: { userId_type_currency: { userId, type: walletType, currency: 'MRU' } } });
      if (!account) continue;
      const value = new Prisma.Decimal(amount);
      const after = account.balance.add(value);
      const transaction = await tx.financialTransaction.create({
        data: {
          userId,
          type: TransactionType.REWARD,
          status: TransactionStatus.COMPLETED,
          amount: value,
          currency: 'MRU',
          description: `${label} reward`,
          processedAt: new Date(),
          metadata: { referenceType, referenceId, walletType },
        },
      });
      await tx.walletAccount.update({ where: { id: account.id }, data: { balance: after, version: { increment: 1 } } });
      await tx.ledgerEntry.create({
        data: {
          userId,
          accountId: account.id,
          transactionId: transaction.id,
          direction: LedgerDirection.CREDIT,
          amount: value,
          balanceBefore: account.balance,
          balanceAfter: after,
          referenceType,
          referenceId,
          description: `${label} reward`,
        },
      });
    }
    const itemCodes = Array.isArray(rewards.itemCodes) ? rewards.itemCodes.map(String) : [];
    if (itemCodes.length) {
      const items = await tx.catalogItem.findMany({ where: { code: { in: itemCodes } } });
      for (const item of items) {
        await tx.userInventory.upsert({
          where: { userId_itemId: { userId, itemId: item.id } },
          update: { quantity: { increment: 1 } },
          create: { userId, itemId: item.id, source: InventorySource.REWARD, quantity: 1 },
        });
      }
    }
    await tx.notification.create({
      data: {
        userId,
        type: NotificationType.SYSTEM,
        title: referenceType === 'LEVEL' ? 'Level up' : 'New stage reached',
        body: `${label} reached.`,
        data: { referenceType, referenceId, rewards } as Prisma.InputJsonValue,
      },
    });
  }

  private async ensureStakeAvailable(userId: string, stakeInput: number) {
    const stake = new Prisma.Decimal(stakeInput);
    const cash = await this.prisma.walletAccount.findUnique({ where: { userId_type_currency: { userId, type: WalletType.CASH, currency: 'MRU' } } });
    if (!cash || cash.balance.lessThan(stake)) throw new BadRequestException('Insufficient cash balance for this wager');
  }

  private async reserveStake(tx: Prisma.TransactionClient, userId: string, stakeInput: number, matchId: string) {
    const stake = new Prisma.Decimal(stakeInput);
    const cash = await tx.walletAccount.findUnique({ where: { userId_type_currency: { userId, type: WalletType.CASH, currency: 'MRU' } } });
    const locked = await tx.walletAccount.findUnique({ where: { userId_type_currency: { userId, type: WalletType.LOCKED, currency: 'MRU' } } });
    if (!cash || !locked || cash.balance.lessThan(stake)) throw new BadRequestException('Insufficient balance');
    const cashAfter = cash.balance.sub(stake);
    const lockedAfter = locked.balance.add(stake);
    const transaction = await tx.financialTransaction.create({ data: { userId, type: TransactionType.WAGER_LOCK, status: TransactionStatus.COMPLETED, amount: stake, description: 'Match wager reserved', processedAt: new Date(), metadata: { matchId } } });
    await tx.walletAccount.update({ where: { id: cash.id }, data: { balance: cashAfter, version: { increment: 1 } } });
    await tx.walletAccount.update({ where: { id: locked.id }, data: { balance: lockedAfter, version: { increment: 1 } } });
    await tx.ledgerEntry.createMany({ data: [
      { userId, accountId: cash.id, transactionId: transaction.id, direction: LedgerDirection.DEBIT, amount: stake, balanceBefore: cash.balance, balanceAfter: cashAfter, referenceType: 'MATCH', referenceId: matchId, description: 'Match wager reserved' },
      { userId, accountId: locked.id, transactionId: transaction.id, direction: LedgerDirection.CREDIT, amount: stake, balanceBefore: locked.balance, balanceAfter: lockedAfter, referenceType: 'MATCH', referenceId: matchId, description: 'Match wager reserved' },
    ] });
  }

  private async cancelMatchUnlocked(match: any, userId: string) {
    const stake = Number(match.stakeAmount);
    return this.prisma.$transaction(async (tx) => {
      const sequence = await this.nextSequence(match.id, tx);
      await tx.match.update({
        where: { id: match.id },
        data: { status: stake > 0 ? MatchStatus.REFUNDED : MatchStatus.CANCELLED, cancelledAt: new Date(), nextActionAt: null },
      });
      await tx.matchPlayer.updateMany({ where: { matchId: match.id }, data: { status: MatchPlayerStatus.FINISHED, finishedAt: new Date() } });
      await tx.matchEvent.create({ data: { matchId: match.id, actorUserId: userId, sequence, type: MatchEventType.MATCH_CANCELLED, payload: { refunded: stake > 0 } } });
      if (stake > 0) {
        for (const player of match.players) await this.refundStake(tx, player.userId, stake, match.id, 'Room cancelled before start');
      }
      await tx.notification.createMany({ data: match.players.map((player: any) => ({
        userId: player.userId,
        type: NotificationType.MATCH,
        title: stake > 0 ? 'Room cancelled and wager refunded' : 'Room cancelled',
        body: `Room ${match.publicCode} was cancelled before the match started.`,
        data: { matchId: match.id },
      })) });
      return { cancelled: true, refunded: stake > 0 };
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
  }

  private async refundStake(
    tx: Prisma.TransactionClient,
    userId: string,
    stakeInput: number,
    matchId: string,
    description: string,
  ) {
    const stake = new Prisma.Decimal(stakeInput);
    const [cash, locked] = await Promise.all([
      tx.walletAccount.findUnique({ where: { userId_type_currency: { userId, type: WalletType.CASH, currency: 'MRU' } } }),
      tx.walletAccount.findUnique({ where: { userId_type_currency: { userId, type: WalletType.LOCKED, currency: 'MRU' } } }),
    ]);
    if (!cash || !locked || locked.balance.lessThan(stake)) throw new BadRequestException('Reserved wager balance is unavailable');
    const cashAfter = cash.balance.add(stake);
    const lockedAfter = locked.balance.sub(stake);
    const transaction = await tx.financialTransaction.create({
      data: {
        userId,
        type: TransactionType.REFUND,
        status: TransactionStatus.COMPLETED,
        amount: stake,
        currency: 'MRU',
        description,
        processedAt: new Date(),
        metadata: { matchId },
      },
    });
    await tx.walletAccount.update({ where: { id: cash.id }, data: { balance: cashAfter, version: { increment: 1 } } });
    await tx.walletAccount.update({ where: { id: locked.id }, data: { balance: lockedAfter, version: { increment: 1 } } });
    await tx.ledgerEntry.createMany({ data: [
      { userId, accountId: locked.id, transactionId: transaction.id, direction: LedgerDirection.DEBIT, amount: stake, balanceBefore: locked.balance, balanceAfter: lockedAfter, referenceType: 'MATCH', referenceId: matchId, description },
      { userId, accountId: cash.id, transactionId: transaction.id, direction: LedgerDirection.CREDIT, amount: stake, balanceBefore: cash.balance, balanceAfter: cashAfter, referenceType: 'MATCH', referenceId: matchId, description },
    ] });
  }

  private async nextSequence(matchId: string, tx: any = this.prisma) {
    const result = await tx.matchEvent.aggregate({ where: { matchId }, _max: { sequence: true } });
    return (result._max.sequence ?? 0) + 1;
  }

  private full(id: string) { return this.prisma.match.findUnique({ where: { id }, include: { players: { include: { user: { select: { username: true, profile: true } } }, orderBy: { seat: 'asc' } }, ruleSet: true, events: { orderBy: { sequence: 'asc' } } } }).then((m) => { if (!m) throw new NotFoundException('Match not found'); return m; }); }
  private rules(r: any): EngineRules { return { piecesPerPlayer: r.piecesPerPlayer, requiresSixToExit: r.requiresSixToExit, extraTurnOnSix: r.extraTurnOnSix, extraTurnOnCapture: r.extraTurnOnCapture, extraTurnOnFinish: r.extraTurnOnFinish, threeSixesLoseTurn: r.threeSixesLoseTurn, exactRollToFinish: r.exactRollToFinish, blockadeEnabled: r.blockadeEnabled, rollSeconds: r.rollSeconds, moveSeconds: r.moveSeconds, finishAllPlayers: r.finishAllPlayers }; }
  private async ensureMatchesEnabled() {
    const maintenance = await this.prisma.appSetting.findUnique({ where: { key: 'maintenance_mode' } });
    if (maintenance?.value === true) throw new BadRequestException('New matches are temporarily disabled');
  }

  private async validateStake(stake: number) {
    const [minimum, maximum] = await Promise.all([
      this.settingNumber('minimum_wager', 50),
      this.settingNumber('maximum_wager', 100000),
    ]);
    if (!Number.isFinite(stake) || stake < minimum || stake > maximum) {
      throw new BadRequestException(`Stake must be between ${minimum} and ${maximum} MRU`);
    }
  }

  private async settingNumber(key: string, fallback: number) { const s = await this.prisma.appSetting.findUnique({ where: { key } }); return typeof s?.value === 'number' ? s.value : fallback; }
  private async uniqueCode() { for (;;) { const code = String(randomInt(100000, 1000000)); if (!(await this.prisma.match.findUnique({ where: { publicCode: code } }))) return code; } }
}
