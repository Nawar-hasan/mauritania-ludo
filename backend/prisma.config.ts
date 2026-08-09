import 'dotenv/config';
import { defineConfig } from 'prisma/config';

export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: {
    path: 'prisma/migrations',
    seed: 'tsx prisma/seed.ts',
  },
  datasource: {
    // `prisma generate` does not need a live database connection.
    // Railway Docker builds do not expose service variables to Docker RUN
    // unless they are explicitly declared as build args, so use a harmless
    // placeholder only when DATABASE_URL is absent during image build.
    // At pre-deploy/runtime Railway provides the real DATABASE_URL.
    url:
      process.env.DATABASE_URL ??
      'postgresql://placeholder:placeholder@localhost:5432/placeholder',
  },
});
