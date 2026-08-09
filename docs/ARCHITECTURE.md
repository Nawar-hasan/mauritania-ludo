# Architecture

## Security boundary

The mobile application is never authoritative for dice, movement, timers, match results or wallet balances. The backend validates every state transition and stores an append-only match event log.

## Main services

- PostgreSQL: durable users, wallets, matches, ledger, settings and audit records.
- Redis: presence, socket sessions, matchmaking coordination and short-lived locks.
- NestJS API: HTTP and Socket.IO gateway.
- Next.js Admin: operational control panel using the same protected API.

## Wallet model

Each user has separate accounts:

- `CASH`: withdrawable cash balance.
- `BONUS`: promotional credit.
- `COINS`: social/store currency.
- `GEMS`: cosmetic premium currency.
- `LOCKED`: funds reserved during matches or pending operations.

Every balance mutation is executed in a database transaction and creates a `LedgerEntry`. Existing ledger entries are never edited or deleted.

## Match state

The state is persisted as JSON on the match row and every action is also appended to `MatchEvent`. Optimistic versioning prevents duplicate or stale actions. The server generates dice results using Node's cryptographic random generator.

## Real-money boundary

The code supports an auditable balance and wager workflow, but payment provider activation and real-money withdrawals remain disabled until jurisdiction, licensing, age/KYC and responsible-play requirements are approved.
