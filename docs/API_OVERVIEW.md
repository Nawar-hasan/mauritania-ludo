# API overview

Base path: `/api/v1`

## Public

- `GET /health`
- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/refresh`

## Authenticated player

- `POST /auth/logout`
- `GET /users/me`
- `PATCH /users/me`
- `POST /users/me/avatar`
- `GET /wallets/me`
- `GET /wallets/me/ledger`
- `POST /matches`
- `POST /matches/:id/join`
- `POST /matches/:id/start`
- `POST /matches/:id/roll`
- `POST /matches/:id/move`
- `POST /matches/:id/forfeit`
- `GET /matches/:id`
- `POST /matchmaking/join`
- `DELETE /matchmaking/:ticketId`

## Admin

- `GET /admin/dashboard`
- `GET /admin/users`
- `PATCH /admin/users/:id/status`
- `POST /admin/wallets/adjust`
- `GET /admin/transactions`
- `GET /admin/matches`
- `GET /admin/matches/:id`
- `GET /admin/settings`
- `PATCH /admin/settings/:key`
- `GET /admin/audit-logs`

Swagger exposes schemas and request examples at `/docs`.
