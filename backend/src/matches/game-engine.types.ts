import { PlayerColor } from '../generated/prisma/client.js';
export type GamePhase = 'ROLL' | 'MOVE' | 'FINISHED';
export type PieceState = { id: number; progress: number };
export type EnginePlayer = { userId: string; color: PlayerColor; pieces: PieceState[]; inactiveTurns: number; finished: boolean };
export type GameState = {
  version: number; players: EnginePlayer[]; turnIndex: number; phase: GamePhase; dice: number | null;
  consecutiveSixes: number; legalPieceIds: number[]; winnerOrder: string[]; lastAction: string;
  turnDeadline: string; moveDeadline: string | null;
};
export type EngineRules = {
  piecesPerPlayer: number; requiresSixToExit: boolean; extraTurnOnSix: boolean; extraTurnOnCapture: boolean;
  extraTurnOnFinish: boolean; threeSixesLoseTurn: boolean; exactRollToFinish: boolean; blockadeEnabled: boolean;
  rollSeconds: number; moveSeconds: number; finishAllPlayers: boolean;
};
