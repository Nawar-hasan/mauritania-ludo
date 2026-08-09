import { BadRequestException } from '@nestjs/common';
import { PlayerColor } from '../generated/prisma/client.js';
import { EngineRules, GameState } from './game-engine.types.js';

const START: Record<PlayerColor, number> = { GREEN: 0, YELLOW: 13, BLUE: 26, RED: 39 };
const SAFE = new Set([0, 8, 13, 21, 26, 34, 39, 47]);
const COLORS: PlayerColor[] = [PlayerColor.GREEN, PlayerColor.YELLOW, PlayerColor.BLUE, PlayerColor.RED];
const nowPlus = (seconds: number) => new Date(Date.now() + seconds * 1000).toISOString();

export class LudoEngine {
  static create(userIds: string[], rules: EngineRules): GameState {
    const selectedColors = userIds.length === 2 ? [PlayerColor.GREEN, PlayerColor.RED] : COLORS;
    return { version: 1, players: userIds.map((userId, i) => ({ userId, color: selectedColors[i], pieces: Array.from({ length: rules.piecesPerPlayer }, (_, id) => ({ id, progress: -1 })), inactiveTurns: 0, finished: false })), turnIndex: 0, phase: 'ROLL', dice: null, consecutiveSixes: 0, legalPieceIds: [], winnerOrder: [], lastAction: 'MATCH_STARTED', turnDeadline: nowPlus(rules.rollSeconds), moveDeadline: null };
  }
  static roll(state: GameState, userId: string, dice: number, rules: EngineRules): GameState {
    this.assertTurn(state, userId, 'ROLL'); if (dice < 1 || dice > 6) throw new BadRequestException('Invalid dice');
    const next = structuredClone(state); next.version++; next.dice = dice; next.lastAction = `DICE_${dice}`;
    next.consecutiveSixes = dice === 6 ? next.consecutiveSixes + 1 : 0;
    if (rules.threeSixesLoseTurn && next.consecutiveSixes >= 3) { next.lastAction = 'THREE_SIXES'; return this.advance(next, rules); }
    const legal = this.legalMoves(next, next.turnIndex, dice, rules); next.legalPieceIds = legal;
    if (!legal.length) return dice === 6 && rules.extraTurnOnSix ? this.resetRoll(next, rules) : this.advance(next, rules);
    next.phase = 'MOVE'; next.moveDeadline = nowPlus(rules.moveSeconds); return next;
  }
  static move(state: GameState, userId: string, pieceId: number, rules: EngineRules): { state: GameState; captured: string[]; finishedPiece: boolean } {
    this.assertTurn(state, userId, 'MOVE'); if (!state.legalPieceIds.includes(pieceId) || !state.dice) throw new BadRequestException('Illegal piece');
    const next = structuredClone(state), player = next.players[next.turnIndex], piece = player.pieces.find((p) => p.id === pieceId)!;
    const before = piece.progress; piece.progress = before === -1 ? 0 : before + state.dice;
    const finishedPiece = piece.progress === 58; const captured: string[] = [];
    if (piece.progress >= 0 && piece.progress <= 51) {
      const global = this.globalIndex(player.color, piece.progress);
      if (!SAFE.has(global)) for (const opponent of next.players.filter((p) => p.userId !== userId)) for (const other of opponent.pieces) if (other.progress >= 0 && other.progress <= 51 && this.globalIndex(opponent.color, other.progress) === global) { other.progress = -1; captured.push(`${opponent.userId}:${other.id}`); }
    }
    if (player.pieces.every((p) => p.progress === 58) && !player.finished) { player.finished = true; next.winnerOrder.push(player.userId); }
    next.version++; next.lastAction = `MOVE_${pieceId}_${before}_${piece.progress}`; next.dice = null; next.legalPieceIds = []; next.moveDeadline = null;
    if (next.winnerOrder.length && (!rules.finishAllPlayers || next.winnerOrder.length >= next.players.length - 1)) { next.phase = 'FINISHED'; next.turnDeadline = new Date().toISOString(); return { state: next, captured, finishedPiece }; }
    const extra = (captured.length > 0 && rules.extraTurnOnCapture) || (finishedPiece && rules.extraTurnOnFinish) || (state.dice === 6 && rules.extraTurnOnSix);
    return { state: extra ? this.resetRoll(next, rules) : this.advance(next, rules), captured, finishedPiece };
  }
  static autoAction(state: GameState, rules: EngineRules, dice: number): GameState {
    const userId = state.players[state.turnIndex].userId;
    if (state.phase === 'ROLL') return this.roll(state, userId, dice, rules);
    if (state.phase === 'MOVE') return this.move(state, userId, state.legalPieceIds[0], rules).state;
    return state;
  }
  static legalMoves(state: GameState, playerIndex: number, dice: number, rules: EngineRules) {
    const player = state.players[playerIndex]; return player.pieces.filter((piece) => {
      if (piece.progress === 58) return false;
      if (piece.progress === -1) return !rules.requiresSixToExit || dice === 6;
      const target = piece.progress + dice; if (target > 58 && rules.exactRollToFinish) return false;
      if (target > 58) return false;
      if (target <= 51 && rules.blockadeEnabled) {
        const globalTarget = this.globalIndex(player.color, target);
        const opponentsAtTarget = state.players.filter((p) => p.userId !== player.userId).flatMap((p) => p.pieces.filter((x) => x.progress >= 0 && x.progress <= 51 && this.globalIndex(p.color, x.progress) === globalTarget));
        if (opponentsAtTarget.length >= 2) return false;
        for (let step = piece.progress + 1; step < target; step++) {
          const global = this.globalIndex(player.color, step);
          const counts = state.players.filter((p) => p.userId !== player.userId).map((p) => p.pieces.filter((x) => x.progress >= 0 && x.progress <= 51 && this.globalIndex(p.color, x.progress) === global).length);
          if (counts.some((n) => n >= 2)) return false;
        }
      }
      return true;
    }).map((p) => p.id);
  }
  private static assertTurn(state: GameState, userId: string, phase: 'ROLL' | 'MOVE') {
    if (state.phase !== phase) throw new BadRequestException(`Expected ${state.phase} action`);
    if (state.players[state.turnIndex]?.userId !== userId) throw new BadRequestException('Not your turn');
  }
  private static globalIndex(color: PlayerColor, progress: number) { return (START[color] + progress) % 52; }
  private static resetRoll(state: GameState, rules: EngineRules) { state.phase = 'ROLL'; state.dice = null; state.legalPieceIds = []; state.turnDeadline = nowPlus(rules.rollSeconds); state.moveDeadline = null; return state; }
  private static advance(state: GameState, rules: EngineRules) {
    state.dice = null; state.legalPieceIds = []; state.consecutiveSixes = 0; state.moveDeadline = null;
    let next = state.turnIndex; do { next = (next + 1) % state.players.length; } while (state.players[next].finished && next !== state.turnIndex);
    state.turnIndex = next; state.phase = 'ROLL'; state.turnDeadline = nowPlus(rules.rollSeconds); return state;
  }
}
