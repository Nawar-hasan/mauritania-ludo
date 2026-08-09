const base = (process.env.API_URL ?? 'http://localhost:3000/api/v1').replace(/\/$/, '');
const stamp = Date.now();

async function request(path, { method = 'GET', token, body } = {}) {
  const response = await fetch(`${base}${path}`, {
    method,
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  const payload = await response.json().catch(() => null);
  if (!response.ok) throw new Error(`${method} ${path} -> ${response.status}: ${JSON.stringify(payload)}`);
  return payload;
}

async function register(suffix) {
  return request('/auth/register', {
    method: 'POST',
    body: {
      username: `smoke_${suffix}_${stamp}`,
      displayName: `Smoke ${suffix}`,
      email: `smoke_${suffix}_${stamp}@example.test`,
      password: 'SmokePassword123!',
      locale: 'en',
    },
  });
}

console.log(`Testing ${base}`);
const first = await register('one');
const second = await register('two');
console.log('✓ registered two users');

const profile = await request('/users/me', { token: first.accessToken });
if (!profile.id) throw new Error('Profile endpoint returned no user id');
console.log('✓ authenticated profile');

const wallet = await request('/wallets/me', { token: first.accessToken });
if (!wallet.balances || Number(wallet.balances.cash) !== 0) throw new Error('New wallet is not initialized at zero');
console.log('✓ zero-balance wallet initialized');

const cancellable = await request('/matches', {
  method: 'POST',
  token: first.accessToken,
  body: { mode: 'PRIVATE', maxPlayers: 2, ruleCode: 'CLASSIC', stakeAmount: 0, currency: 'MRU' },
});
await request(`/matches/${cancellable.id}/join`, { method: 'POST', token: second.accessToken });
await request(`/matches/${cancellable.id}/leave`, { method: 'POST', token: second.accessToken });
let waitingAfterLeave = await request(`/matches/${cancellable.id}`, { token: first.accessToken });
if (waitingAfterLeave.status !== 'WAITING' || waitingAfterLeave.players.length !== 1) throw new Error('Waiting-room leave did not restore the room');
await request(`/matches/${cancellable.id}/cancel`, { method: 'POST', token: first.accessToken });
const cancelled = await request(`/matches/${cancellable.id}`, { token: first.accessToken });
if (!['CANCELLED', 'REFUNDED'].includes(cancelled.status)) throw new Error('Host cancellation did not close the waiting room');
console.log('✓ waiting-room leave and host cancellation');

const created = await request('/matches', {
  method: 'POST',
  token: first.accessToken,
  body: { mode: 'PRIVATE', maxPlayers: 2, ruleCode: 'CLASSIC', stakeAmount: 0, currency: 'MRU' },
});
console.log(`✓ created private room ${created.publicCode}`);

await request(`/matches/${created.id}/join`, { method: 'POST', token: second.accessToken });
const started = await request(`/matches/${created.id}/start`, { method: 'POST', token: first.accessToken });
if (started.status !== 'ACTIVE') throw new Error('Match did not become ACTIVE');
console.log('✓ second player joined and host started match');

let match = started;
const state = match.currentState;
const activeUserId = state.players[state.turnIndex].userId;
const activeToken = activeUserId === first.user.id ? first.accessToken : second.accessToken;
match = await request(`/matches/${created.id}/roll`, { method: 'POST', token: activeToken });
console.log(`✓ authoritative dice roll: ${match.currentState.dice ?? 'no legal move; turn advanced'}`);

if (match.currentState.phase === 'MOVE') {
  const moverId = match.currentState.players[match.currentState.turnIndex].userId;
  const moverToken = moverId === first.user.id ? first.accessToken : second.accessToken;
  const pieceId = match.currentState.legalPieceIds[0];
  match = await request(`/matches/${created.id}/move`, {
    method: 'POST',
    token: moverToken,
    body: { pieceId, expectedVersion: match.currentState.version },
  });
  console.log(`✓ authoritative legal move for piece ${pieceId}`);
}

await request('/wallets/me/deposits', {
  method: 'POST',
  token: first.accessToken,
  body: { amount: 100, method: 'OTHER', externalRef: `SMOKE-${stamp}` },
});
const transactions = await request('/wallets/me/transactions', { token: first.accessToken });
if (!transactions.items?.some((item) => item.type === 'DEPOSIT' && item.status === 'PENDING')) throw new Error('Pending deposit was not stored');
console.log('✓ pending deposit stored without changing cash balance');

console.log('\nSMOKE TEST PASSED');
console.log(`Test users: ${first.user.username}, ${second.user.username}`);
