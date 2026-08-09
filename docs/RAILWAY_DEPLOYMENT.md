# Railway deployment

## Services

Create one Railway project with:

1. PostgreSQL service.
2. Redis service.
3. API service rooted at `/backend`.
4. Admin service rooted at `/admin`.
5. Optional persistent volume mounted at `/app/uploads` for local avatar uploads.

## API variables

Copy all keys from `backend/.env.example` and set:

```env
DATABASE_URL=${{Postgres.DATABASE_URL}}
REDIS_URL=${{Redis.REDIS_URL}}
PUBLIC_API_URL=https://YOUR-API-DOMAIN
CORS_ORIGINS=https://YOUR-ADMIN-DOMAIN
UPLOAD_DIR=/app/uploads
```

Use long random values for JWT secrets. Set the API service pre-deploy command to:

```bash
npm run db:deploy
```

Start command:

```bash
npm run start:prod
```

Generate a public domain after the first successful deploy.

## Admin variables

```env
NEXT_PUBLIC_API_URL=https://YOUR-API-DOMAIN/api/v1
```

Start command:

```bash
npm run start
```

## First administrator

Set `SEED_ADMIN_EMAIL`, `SEED_ADMIN_USERNAME` and `SEED_ADMIN_PASSWORD` temporarily on the API service, run the seed command once, then remove the password variable.

```bash
npm run db:seed
```

## Flutter

The mobile app should use:

```text
https://YOUR-API-DOMAIN/api/v1
```

Never place JWT secrets, database credentials or administrator credentials inside Flutter.
