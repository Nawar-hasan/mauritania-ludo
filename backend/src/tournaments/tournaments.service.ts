import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { randomInt } from 'node:crypto';
import {
  IdentityVerificationStatus,
  LedgerDirection,
  MatchEventType,
  MatchMode,
  MatchPlayerStatus,
  MatchStatus,
  NotificationType,
  PlayerColor,
  Prisma,
  TournamentEntryStatus,
  TournamentPairingStatus,
  TournamentStatus,
  TransactionStatus,
  TransactionType,
  WalletType,
} from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { RedisService } from '../redis/redis.service.js';
import { CreateTournamentDto } from './dto/tournament.dto.js';

@Injectable()
export class TournamentsService {
  constructor(private readonly prisma: PrismaService, private readonly redis: RedisService) {}

  async list(userId: string) {
    const rows = await this.prisma.tournament.findMany({ where: { status: { not: TournamentStatus.DRAFT } }, orderBy: [{ sortOrder: 'asc' }, { startsAt: 'asc' }, { createdAt: 'desc' }] });
    const ids = rows.map((x) => x.id);
    const [entries, counts] = await Promise.all([
      ids.length ? this.prisma.tournamentEntry.findMany({ where: { tournamentId: { in: ids }, userId } }) : [],
      Promise.all(ids.map(async (id) => [id, await this.prisma.tournamentEntry.count({ where: { tournamentId: id, status: { not: TournamentEntryStatus.WITHDRAWN } } })] as const)),
    ]);
    const joined = new Set(entries.map((x) => x.tournamentId));
    const countMap = new Map(counts);
    return { items: rows.map((x) => ({ ...x, joined: joined.has(x.id), entrants: countMap.get(x.id) ?? 0 })) };
  }

  async details(id: string, userId: string) {
    await this.sync(id).catch(() => undefined);
    const tournament = await this.prisma.tournament.findUnique({ where: { id } });
    if (!tournament) throw new NotFoundException('Tournament not found');
    const [entries, pairings] = await Promise.all([
      this.prisma.tournamentEntry.findMany({ where: { tournamentId: id }, orderBy: [{ seed: 'asc' }, { joinedAt: 'asc' }] }),
      this.prisma.tournamentPairing.findMany({ where: { tournamentId: id }, orderBy: [{ roundNumber: 'asc' }, { position: 'asc' }] }),
    ]);
    const userIds = new Set<string>();
    entries.forEach((x) => userIds.add(x.userId));
    pairings.forEach((x) => { if (x.playerAUserId) userIds.add(x.playerAUserId); if (x.playerBUserId) userIds.add(x.playerBUserId); if (x.winnerUserId) userIds.add(x.winnerUserId); });
    const users = userIds.size ? await this.prisma.user.findMany({ where: { id: { in: [...userIds] } }, select: { id: true, username: true, profile: true } }) : [];
    const map = new Map(users.map((u) => [u.id, u]));
    return {
      ...tournament,
      entrants: entries.length,
      joined: entries.some((x) => x.userId === userId && x.status !== TournamentEntryStatus.WITHDRAWN),
      entries: entries.map((x) => ({ ...x, user: map.get(x.userId) ?? null })),
      pairings: pairings.map((x) => ({ ...x, playerA: x.playerAUserId ? map.get(x.playerAUserId) ?? null : null, playerB: x.playerBUserId ? map.get(x.playerBUserId) ?? null : null, winner: x.winnerUserId ? map.get(x.winnerUserId) ?? null : null })),
    };
  }

  async join(id: string, userId: string) {
    return this.redis.withLock(`tournament:${id}:join`, 5000, async () => {
      const tournament = await this.prisma.tournament.findUnique({ where: { id } });
      if (!tournament) throw new NotFoundException('Tournament not found');
      if (tournament.status !== TournamentStatus.OPEN) throw new BadRequestException('Tournament registration is not open');
      const now = new Date();
      if (tournament.registrationOpensAt && tournament.registrationOpensAt > now) throw new BadRequestException('Tournament registration has not opened yet');
      if (tournament.registrationClosesAt && tournament.registrationClosesAt <= now) throw new BadRequestException('Tournament registration is closed');
      const existing = await this.prisma.tournamentEntry.findUnique({ where: { tournamentId_userId: { tournamentId: id, userId } } });
      if (existing && existing.status !== TournamentEntryStatus.WITHDRAWN) return existing;
      if (existing?.status === TournamentEntryStatus.WITHDRAWN) throw new BadRequestException('You cannot rejoin after withdrawing from this tournament');
      const count = await this.prisma.tournamentEntry.count({ where: { tournamentId: id, status: { not: TournamentEntryStatus.WITHDRAWN } } });
      if (count >= tournament.maxPlayers) throw new ConflictException('Tournament is full');
      const fee = Number(tournament.entryFee);
      if (fee > 0) await this.ensureCashEntryEligibility(userId);
      return this.prisma.$transaction(async (tx) => {
        if (fee > 0) await this.lockEntryFee(tx, userId, fee, tournament.currency, id);
        const row = existing
          ? await tx.tournamentEntry.update({ where: { id: existing.id }, data: { status: TournamentEntryStatus.REGISTERED, joinedAt: new Date(), eliminatedAt: null, placement: null } })
          : await tx.tournamentEntry.create({ data: { tournamentId: id, userId } });
        await tx.notification.create({ data: { userId, type: NotificationType.TOURNAMENT, title: 'Tournament joined', body: `You joined ${tournament.nameEn}.`, data: { tournamentId: id } } });
        return row;
      }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    });
  }

  async withdraw(id: string, userId: string) {
    return this.redis.withLock(`tournament:${id}:join`, 5000, async () => {
      const tournament = await this.prisma.tournament.findUnique({ where: { id } });
      if (!tournament) throw new NotFoundException('Tournament not found');
      if (tournament.status !== TournamentStatus.OPEN) throw new BadRequestException('You cannot withdraw after the tournament starts');
      const entry = await this.prisma.tournamentEntry.findUnique({ where: { tournamentId_userId: { tournamentId: id, userId } } });
      if (!entry || entry.status === TournamentEntryStatus.WITHDRAWN) return { withdrawn: true };
      const fee = Number(tournament.entryFee);
      await this.prisma.$transaction(async (tx) => {
        await tx.tournamentEntry.update({ where: { id: entry.id }, data: { status: TournamentEntryStatus.WITHDRAWN } });
        if (fee > 0) await this.refundEntryFee(tx, userId, fee, tournament.currency, id, 'Tournament registration withdrawn');
      }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
      return { withdrawn: true };
    });
  }

  adminList() { return this.prisma.tournament.findMany({ orderBy: [{ createdAt: 'desc' }] }); }
  create(dto: CreateTournamentDto) {
    this.validateDefinition(dto);
    return this.prisma.tournament.create({ data: this.data(dto) });
  }
  update(id: string, dto: CreateTournamentDto) {
    this.validateDefinition(dto);
    return this.prisma.tournament.update({ where: { id }, data: this.data(dto) });
  }
  open(id: string) { return this.prisma.tournament.update({ where: { id }, data: { status: TournamentStatus.OPEN } }); }

  async start(id: string) {
    return this.redis.withLock(`tournament:${id}`, 10000, async () => {
      const tournament = await this.prisma.tournament.findUnique({ where: { id } });
      if (!tournament) throw new NotFoundException('Tournament not found');
      if (tournament.status !== TournamentStatus.OPEN && tournament.status !== TournamentStatus.DRAFT) throw new BadRequestException('Tournament cannot be started');
      const entries = await this.prisma.tournamentEntry.findMany({ where: { tournamentId: id, status: TournamentEntryStatus.REGISTERED }, orderBy: { joinedAt: 'asc' } });
      if (entries.length < tournament.minPlayers) throw new BadRequestException(`At least ${tournament.minPlayers} players are required`);
      if (tournament.matchPlayers !== 2) throw new BadRequestException('V8 tournament bracket currently uses head-to-head matches');
      const rules = await this.prisma.gameRuleSet.findUnique({ where: { code: tournament.ruleCode } });
      if (!rules?.enabled) throw new BadRequestException('Tournament rule set is unavailable');
      const seeded = entries.map((entry, index) => ({ ...entry, seed: index + 1 }));
      await this.prisma.$transaction(seeded.map((entry) => this.prisma.tournamentEntry.update({ where: { id: entry.id }, data: { seed: entry.seed, status: TournamentEntryStatus.ACTIVE } })));
      await this.prisma.tournamentPairing.deleteMany({ where: { tournamentId: id } });
      await this.createRound(id, 1, seeded.map((x) => x.userId), tournament.ruleCode);
      await this.prisma.tournament.update({ where: { id }, data: { status: TournamentStatus.ACTIVE, startsAt: tournament.startsAt ?? new Date() } });
      return this.details(id, seeded[0]!.userId);
    });
  }

  async cancel(id: string) {
    return this.redis.withLock(`tournament:${id}`, 10000, async () => {
      const tournament = await this.prisma.tournament.findUnique({ where: { id } });
      if (!tournament) throw new NotFoundException('Tournament not found');
      if (tournament.status === TournamentStatus.COMPLETED) throw new BadRequestException('Completed tournament cannot be cancelled');
      const entries = await this.prisma.tournamentEntry.findMany({ where: { tournamentId: id, status: { not: TournamentEntryStatus.WITHDRAWN } } });
      const fee = Number(tournament.entryFee);
      await this.prisma.$transaction(async (tx) => {
        await tx.tournament.update({ where: { id }, data: { status: TournamentStatus.CANCELLED } });
        await tx.tournamentPairing.updateMany({ where: { tournamentId: id, status: { not: TournamentPairingStatus.COMPLETED } }, data: { status: TournamentPairingStatus.CANCELLED } });
        if (fee > 0) for (const entry of entries) await this.refundEntryFee(tx, entry.userId, fee, tournament.currency, id, 'Tournament cancelled');
      }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
      return { cancelled: true };
    });
  }

  @Interval(15000)
  async syncActiveTournaments() {
    const active = await this.prisma.tournament.findMany({ where: { status: TournamentStatus.ACTIVE }, select: { id: true }, take: 100 });
    for (const row of active) await this.sync(row.id).catch(() => undefined);
  }

  async sync(id: string) {
    const tournament = await this.prisma.tournament.findUnique({ where: { id } });
    if (!tournament || tournament.status !== TournamentStatus.ACTIVE) return tournament;
    return this.redis.withLock(`tournament:${id}:sync`, 10000, async () => {
      let pairings = await this.prisma.tournamentPairing.findMany({ where: { tournamentId: id }, orderBy: [{ roundNumber: 'asc' }, { position: 'asc' }] });
      const unresolved = pairings.filter((p) => p.matchId && !p.winnerUserId && (p.status === TournamentPairingStatus.READY || p.status === TournamentPairingStatus.ACTIVE || p.status === TournamentPairingStatus.PENDING));
      for (const pairing of unresolved) {
        const match = await this.prisma.match.findUnique({ where: { id: pairing.matchId! } });
        if (!match) continue;
        if (match.status === MatchStatus.ACTIVE && pairing.status !== TournamentPairingStatus.ACTIVE) await this.prisma.tournamentPairing.update({ where: { id: pairing.id }, data: { status: TournamentPairingStatus.ACTIVE } });
        if (match.status === MatchStatus.COMPLETED && match.winnerUserId) {
          await this.prisma.tournamentPairing.update({ where: { id: pairing.id }, data: { status: TournamentPairingStatus.COMPLETED, winnerUserId: match.winnerUserId } });
          const loser = pairing.playerAUserId === match.winnerUserId ? pairing.playerBUserId : pairing.playerAUserId;
          if (loser) await this.prisma.tournamentEntry.updateMany({ where: { tournamentId: id, userId: loser }, data: { status: TournamentEntryStatus.ELIMINATED, eliminatedAt: new Date() } });
        }
      }
      pairings = await this.prisma.tournamentPairing.findMany({ where: { tournamentId: id }, orderBy: [{ roundNumber: 'asc' }, { position: 'asc' }] });
      const maxRound = pairings.reduce((m, p) => Math.max(m, p.roundNumber), 0);
      const current = pairings.filter((p) => p.roundNumber === maxRound);
      if (!current.length || current.some((p) => !p.winnerUserId)) return tournament;
      const winners = current.map((p) => p.winnerUserId!).filter(Boolean);
      if (winners.length === 1) {
        await this.completeTournament(tournament, winners[0]!);
        return this.prisma.tournament.findUnique({ where: { id } });
      }
      const nextExists = pairings.some((p) => p.roundNumber === maxRound + 1);
      if (!nextExists) await this.createRound(id, maxRound + 1, winners, tournament.ruleCode);
      return tournament;
    });
  }

  private async createRound(tournamentId: string, roundNumber: number, users: string[], ruleCode: string) {
    const power = this.nextPowerOfTwo(users.length);
    const padded: Array<string | null> = [...users, ...Array(power - users.length).fill(null)];
    const pairs: Array<[string | null, string | null]> = [];
    for (let i = 0; i < padded.length; i += 2) pairs.push([padded[i] ?? null, padded[i + 1] ?? null]);
    for (let index = 0; index < pairs.length; index++) {
      const [a, b] = pairs[index]!;
      if (a && !b) {
        await this.prisma.tournamentPairing.create({ data: { tournamentId, roundNumber, position: index + 1, playerAUserId: a, winnerUserId: a, status: TournamentPairingStatus.BYE } });
        continue;
      }
      if (!a || !b) continue;
      const match = await this.createTournamentMatch([a, b], ruleCode, tournamentId, roundNumber, index + 1);
      await this.prisma.tournamentPairing.create({ data: { tournamentId, roundNumber, position: index + 1, playerAUserId: a, playerBUserId: b, matchId: match.id, status: TournamentPairingStatus.READY } });
      await this.prisma.notification.createMany({ data: [a, b].map((userId) => ({ userId, type: NotificationType.TOURNAMENT, title: 'Tournament match ready', body: `Round ${roundNumber} is ready.`, data: { tournamentId, matchId: match.id } })) });
    }
  }

  private async createTournamentMatch(users: string[], ruleCode: string, tournamentId: string, roundNumber: number, position: number) {
    const rules = await this.prisma.gameRuleSet.findUnique({ where: { code: ruleCode } });
    if (!rules) throw new BadRequestException('Tournament rule set not found');
    return this.prisma.match.create({ data: {
      publicCode: await this.uniqueMatchCode(),
      mode: MatchMode.TOURNAMENT,
      status: MatchStatus.READY,
      maxPlayers: 2,
      stakeAmount: 0,
      currency: 'MRU',
      platformFeeRate: 0,
      ruleSetId: rules.id,
      players: { create: [
        { userId: users[0]!, seat: 0, color: PlayerColor.GREEN, status: MatchPlayerStatus.JOINED },
        { userId: users[1]!, seat: 1, color: PlayerColor.RED, status: MatchPlayerStatus.JOINED },
      ] },
      events: { create: { sequence: 1, type: MatchEventType.MATCH_CREATED, actorUserId: users[0]!, payload: { source: 'TOURNAMENT', tournamentId, roundNumber, position } } },
    } });
  }

  private async completeTournament(tournament: any, winnerUserId: string) {
    const entries = await this.prisma.tournamentEntry.findMany({ where: { tournamentId: tournament.id, status: { not: TournamentEntryStatus.WITHDRAWN } } });
    const fee = Number(tournament.entryFee);
    const prize = fee * entries.length;
    await this.prisma.$transaction(async (tx) => {
      await tx.tournament.update({ where: { id: tournament.id }, data: { status: TournamentStatus.COMPLETED, completedAt: new Date(), prizePool: prize } });
      await tx.tournamentEntry.updateMany({ where: { tournamentId: tournament.id, userId: winnerUserId }, data: { status: TournamentEntryStatus.WINNER, placement: 1 } });
      if (fee > 0) {
        for (const entry of entries) await this.consumeEntryFee(tx, entry.userId, fee, tournament.currency, tournament.id);
        await this.creditPrize(tx, winnerUserId, prize, tournament.currency, tournament.id);
      }
      await tx.notification.create({ data: { userId: winnerUserId, type: NotificationType.TOURNAMENT, title: 'Tournament champion', body: `You won ${tournament.nameEn}.`, data: { tournamentId: tournament.id, prize } } });
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
  }

  private validateDefinition(dto: CreateTournamentDto) {
    const minPlayers = dto.minPlayers ?? 2;
    const maxPlayers = dto.maxPlayers ?? 16;
    if (minPlayers > maxPlayers) throw new BadRequestException('Minimum players cannot exceed maximum players');
    if ((dto.matchPlayers ?? 2) !== 2) throw new BadRequestException('Tournament matches currently support exactly two players');
    const opens = dto.registrationOpensAt ? new Date(dto.registrationOpensAt) : null;
    const closes = dto.registrationClosesAt ? new Date(dto.registrationClosesAt) : null;
    const starts = dto.startsAt ? new Date(dto.startsAt) : null;
    if (opens && closes && opens >= closes) throw new BadRequestException('Registration closing time must be after opening time');
    if (closes && starts && closes > starts) throw new BadRequestException('Tournament start time cannot be before registration closes');
  }

  private data(dto: CreateTournamentDto) {
    return {
      code: dto.code.trim().toUpperCase(), nameAr: dto.nameAr.trim(), nameEn: dto.nameEn.trim(), descriptionAr: dto.descriptionAr, descriptionEn: dto.descriptionEn, imageUrl: dto.imageUrl,
      ruleCode: dto.ruleCode ?? 'CLASSIC', matchPlayers: dto.matchPlayers ?? 2, minPlayers: dto.minPlayers ?? 2, maxPlayers: dto.maxPlayers ?? 16,
      entryFee: dto.entryFee ?? 0, currency: dto.currency ?? 'MRU', registrationOpensAt: dto.registrationOpensAt ? new Date(dto.registrationOpensAt) : null,
      registrationClosesAt: dto.registrationClosesAt ? new Date(dto.registrationClosesAt) : null, startsAt: dto.startsAt ? new Date(dto.startsAt) : null, sortOrder: dto.sortOrder ?? 0,
    };
  }

  private async lockEntryFee(tx: Prisma.TransactionClient, userId: string, amountInput: number, currency: string, tournamentId: string) {
    const amount = new Prisma.Decimal(amountInput);
    const [cash, locked] = await Promise.all([
      tx.walletAccount.findUnique({ where: { userId_type_currency: { userId, type: WalletType.CASH, currency } } }),
      tx.walletAccount.findUnique({ where: { userId_type_currency: { userId, type: WalletType.LOCKED, currency } } }),
    ]);
    if (!cash || !locked || cash.balance.lessThan(amount)) throw new BadRequestException('Insufficient balance for tournament entry');
    const cashAfter = cash.balance.sub(amount), lockedAfter = locked.balance.add(amount);
    const transaction = await tx.financialTransaction.create({ data: { userId, type: TransactionType.WAGER_LOCK, status: TransactionStatus.COMPLETED, amount, currency, description: 'Tournament entry locked', processedAt: new Date(), idempotencyKey: `tournament:${tournamentId}:entry:${userId}` } });
    await tx.walletAccount.update({ where: { id: cash.id }, data: { balance: cashAfter, version: { increment: 1 } } });
    await tx.walletAccount.update({ where: { id: locked.id }, data: { balance: lockedAfter, version: { increment: 1 } } });
    await tx.ledgerEntry.createMany({ data: [
      { userId, accountId: cash.id, transactionId: transaction.id, direction: LedgerDirection.DEBIT, amount, balanceBefore: cash.balance, balanceAfter: cashAfter, referenceType: 'TOURNAMENT', referenceId: tournamentId, description: 'Tournament entry locked' },
      { userId, accountId: locked.id, transactionId: transaction.id, direction: LedgerDirection.CREDIT, amount, balanceBefore: locked.balance, balanceAfter: lockedAfter, referenceType: 'TOURNAMENT', referenceId: tournamentId, description: 'Tournament entry locked' },
    ] });
  }

  private async refundEntryFee(tx: Prisma.TransactionClient, userId: string, amountInput: number, currency: string, tournamentId: string, description: string) {
    const existing = await tx.financialTransaction.findUnique({ where: { idempotencyKey: `tournament:${tournamentId}:refund:${userId}` } });
    if (existing) return;
    const amount = new Prisma.Decimal(amountInput);
    const [cash, locked] = await Promise.all([
      tx.walletAccount.findUnique({ where: { userId_type_currency: { userId, type: WalletType.CASH, currency } } }),
      tx.walletAccount.findUnique({ where: { userId_type_currency: { userId, type: WalletType.LOCKED, currency } } }),
    ]);
    if (!cash || !locked || locked.balance.lessThan(amount)) return;
    const cashAfter = cash.balance.add(amount), lockedAfter = locked.balance.sub(amount);
    const transaction = await tx.financialTransaction.create({ data: { userId, type: TransactionType.REFUND, status: TransactionStatus.COMPLETED, amount, currency, description, processedAt: new Date(), idempotencyKey: `tournament:${tournamentId}:refund:${userId}` } });
    await tx.walletAccount.update({ where: { id: cash.id }, data: { balance: cashAfter, version: { increment: 1 } } });
    await tx.walletAccount.update({ where: { id: locked.id }, data: { balance: lockedAfter, version: { increment: 1 } } });
    await tx.ledgerEntry.createMany({ data: [
      { userId, accountId: locked.id, transactionId: transaction.id, direction: LedgerDirection.DEBIT, amount, balanceBefore: locked.balance, balanceAfter: lockedAfter, referenceType: 'TOURNAMENT', referenceId: tournamentId, description },
      { userId, accountId: cash.id, transactionId: transaction.id, direction: LedgerDirection.CREDIT, amount, balanceBefore: cash.balance, balanceAfter: cashAfter, referenceType: 'TOURNAMENT', referenceId: tournamentId, description },
    ] });
  }

  private async consumeEntryFee(tx: Prisma.TransactionClient, userId: string, amountInput: number, currency: string, tournamentId: string) {
    const amount = new Prisma.Decimal(amountInput);
    const locked = await tx.walletAccount.findUnique({ where: { userId_type_currency: { userId, type: WalletType.LOCKED, currency } } });
    if (!locked || locked.balance.lessThan(amount)) throw new BadRequestException('Tournament locked balance is inconsistent');
    const after = locked.balance.sub(amount);
    const transaction = await tx.financialTransaction.create({ data: { userId, type: TransactionType.WAGER_RELEASE, status: TransactionStatus.COMPLETED, amount, currency, description: 'Tournament entry settled', processedAt: new Date(), idempotencyKey: `tournament:${tournamentId}:settle:${userId}` } });
    await tx.walletAccount.update({ where: { id: locked.id }, data: { balance: after, version: { increment: 1 } } });
    await tx.ledgerEntry.create({ data: { userId, accountId: locked.id, transactionId: transaction.id, direction: LedgerDirection.DEBIT, amount, balanceBefore: locked.balance, balanceAfter: after, referenceType: 'TOURNAMENT', referenceId: tournamentId, description: 'Tournament entry settled' } });
  }

  private async creditPrize(tx: Prisma.TransactionClient, userId: string, amountInput: number, currency: string, tournamentId: string) {
    if (amountInput <= 0) return;
    const amount = new Prisma.Decimal(amountInput);
    const cash = await tx.walletAccount.findUnique({ where: { userId_type_currency: { userId, type: WalletType.CASH, currency } } });
    if (!cash) throw new NotFoundException('Winner wallet not found');
    const after = cash.balance.add(amount);
    const transaction = await tx.financialTransaction.create({ data: { userId, type: TransactionType.MATCH_PRIZE, status: TransactionStatus.COMPLETED, amount, currency, description: 'Tournament prize', processedAt: new Date(), idempotencyKey: `tournament:${tournamentId}:prize:${userId}` } });
    await tx.walletAccount.update({ where: { id: cash.id }, data: { balance: after, version: { increment: 1 } } });
    await tx.ledgerEntry.create({ data: { userId, accountId: cash.id, transactionId: transaction.id, direction: LedgerDirection.CREDIT, amount, balanceBefore: cash.balance, balanceAfter: after, referenceType: 'TOURNAMENT', referenceId: tournamentId, description: 'Tournament prize' } });
  }

  private async ensureCashEntryEligibility(userId: string) {
    const [realMoney, testMode, kycRequired] = await Promise.all([
      this.prisma.appSetting.findUnique({ where: { key: 'real_money_enabled' } }),
      this.prisma.appSetting.findUnique({ where: { key: 'wager_test_mode' } }),
      this.prisma.appSetting.findUnique({ where: { key: 'kyc_required_for_wager' } }),
    ]);
    if (realMoney?.value !== true && testMode?.value !== true) throw new BadRequestException('Cash tournament entries are disabled by administration');
    if (realMoney?.value === true && kycRequired?.value !== false) {
      const verification = await this.prisma.identityVerification.findUnique({ where: { userId } });
      if (verification?.status !== IdentityVerificationStatus.VERIFIED) throw new BadRequestException('Identity verification is required for paid tournaments');
    }
  }

  private nextPowerOfTwo(value: number) { let p = 1; while (p < value) p *= 2; return p; }
  private async uniqueMatchCode() { for (;;) { const code = String(randomInt(100000, 1000000)); if (!(await this.prisma.match.findUnique({ where: { publicCode: code } }))) return code; } }
}
