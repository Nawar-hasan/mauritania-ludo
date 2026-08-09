import { LudoEngine } from './ludo-engine.js';

const rules = {
  piecesPerPlayer: 4,
  requiresSixToExit: true,
  extraTurnOnSix: true,
  extraTurnOnCapture: true,
  extraTurnOnFinish: false,
  threeSixesLoseTurn: true,
  exactRollToFinish: true,
  blockadeEnabled: true,
  rollSeconds: 12,
  moveSeconds: 15,
  finishAllPlayers: false,
};

describe('LudoEngine', () => {
  it('requires six to leave base', () => {
    const state = LudoEngine.create(['a', 'b'], rules);
    expect(LudoEngine.roll(state, 'a', 4, rules).turnIndex).toBe(1);
  });

  it('allows a piece to leave on six', () => {
    const state = LudoEngine.roll(LudoEngine.create(['a', 'b'], rules), 'a', 6, rules);
    expect(state.legalPieceIds).toEqual([0, 1, 2, 3]);
    const moved = LudoEngine.move(state, 'a', 0, rules).state;
    expect(moved.players[0].pieces[0].progress).toBe(0);
    expect(moved.turnIndex).toBe(0);
  });

  it('cancels the third consecutive six', () => {
    let state = LudoEngine.create(['a', 'b'], rules);
    for (let index = 0; index < 2; index++) {
      state = LudoEngine.roll(state, 'a', 6, rules);
      state = LudoEngine.move(state, 'a', index, rules).state;
    }
    state = LudoEngine.roll(state, 'a', 6, rules);
    expect(state.lastAction).toBe('THREE_SIXES');
    expect(state.turnIndex).toBe(1);
    expect(state.dice).toBeNull();
  });

  it('captures an opponent on an unsafe cell', () => {
    let state = LudoEngine.create(['a', 'b'], rules);
    state.players[0].pieces[0].progress = 4; // GREEN global 4
    state.players[1].pieces[0].progress = 18; // RED global 5
    state = LudoEngine.roll(state, 'a', 1, rules);
    const result = LudoEngine.move(state, 'a', 0, rules);
    expect(result.captured).toEqual(['b:0']);
    expect(result.state.players[1].pieces[0].progress).toBe(-1);
    expect(result.state.turnIndex).toBe(0);
  });

  it('does not capture on a safe cell', () => {
    let state = LudoEngine.create(['a', 'b'], rules);
    state.players[0].pieces[0].progress = 7; // GREEN global 7
    state.players[1].pieces[0].progress = 21; // RED global 8, a safe cell
    state = LudoEngine.roll(state, 'a', 1, rules);
    const result = LudoEngine.move(state, 'a', 0, rules);
    expect(result.captured).toEqual([]);
    expect(result.state.players[1].pieces[0].progress).toBe(21);
  });

  it('prevents landing on an opponent blockade', () => {
    let state = LudoEngine.create(['a', 'b'], rules);
    state.players[0].pieces[0].progress = 3;
    state.players[1].pieces[0].progress = 18;
    state.players[1].pieces[1].progress = 18;
    state = LudoEngine.roll(state, 'a', 2, rules);
    expect(state.legalPieceIds).not.toContain(0);
  });

  it('rejects overshooting home', () => {
    let state = LudoEngine.create(['a', 'b'], rules);
    state.players[0].pieces[0].progress = 57;
    state = LudoEngine.roll(state, 'a', 2, rules);
    expect(state.turnIndex).toBe(1);
  });

  it('finishes only with the exact roll and detects the winner', () => {
    let state = LudoEngine.create(['a', 'b'], rules);
    state.players[0].pieces[0].progress = 57;
    state.players[0].pieces[1].progress = 58;
    state.players[0].pieces[2].progress = 58;
    state.players[0].pieces[3].progress = 58;
    state = LudoEngine.roll(state, 'a', 1, rules);
    state = LudoEngine.move(state, 'a', 0, rules).state;
    expect(state.players[0].pieces[0].progress).toBe(58);
    expect(state.phase).toBe('FINISHED');
    expect(state.winnerOrder).toEqual(['a']);
  });
});
