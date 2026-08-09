# Ludo Champion Platform

This repository contains the first real backend foundation for the Ludo Champion application.

- `mobile/` — Flutter application connected to the real API; local mock gameplay and fake account/wallet data are removed.
- `backend/` — NestJS API, PostgreSQL/Prisma, Redis, WebSockets, wallets, matches and admin APIs.
- `admin/` — Next.js administration dashboard.
- `docker-compose.yml` — local PostgreSQL and Redis.
- `docs/` — deployment and integration notes.

## Current scope

This version removes the need for server-side mock users or mock transactions. The seed creates only:

- the initial administrator, when seed environment variables are supplied;
- default game rules;
- required application settings.

Wallets begin at zero. Test credit must be granted explicitly from the admin API/dashboard and is recorded in the immutable ledger.

## Local startup

1. Copy `backend/.env.example` to `backend/.env`.
2. Start infrastructure:

```bash
docker compose up -d
```

3. Start API:

```bash
cd backend
npm install
npx prisma generate
npx prisma migrate deploy
npm run db:seed
npm run start:dev
```

4. Start admin:

```bash
cd admin
npm install
cp .env.example .env.local
npm run dev
```

API documentation: `http://localhost:3000/docs`
Admin dashboard: `http://localhost:3001`

For the easiest Windows flow, run `setup_local_windows.bat` once, then `start_all_windows.bat`. See `docs/CONNECTED_TEST_AR.md` for the full connected test and `docs/RAILWAY_DEPLOYMENT.md` before deployment.


## Connected test order

1. Register two separate player accounts.
2. Give test credit only through the admin wallet adjustment page when testing wagers.
3. Test a private no-wager room: join, leave, cancel, create again, start and finish/forfeit.
4. Submit a deposit request and approve/reject it from the admin dashboard.
5. Build the Flutter APK with the computer LAN IPv4 address or the Railway API URL.

The store, tournaments, voice rooms, referrals, support tickets and OTP recovery are deliberately disabled instead of showing invented data.
