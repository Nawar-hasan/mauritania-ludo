import { z } from 'zod';

const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(3000),
  DATABASE_URL: z.string().min(1),
  REDIS_URL: z.string().min(1),
  JWT_ACCESS_SECRET: z.string().min(24),
  JWT_REFRESH_SECRET: z.string().min(24),
  JWT_ACCESS_TTL_SECONDS: z.coerce.number().int().positive().default(900),
  JWT_REFRESH_TTL_SECONDS: z.coerce.number().int().positive().default(2592000),
  CORS_ORIGINS: z.string().default('http://localhost:3001'),
  PUBLIC_API_URL: z.string().url().default('http://localhost:3000'),
  UPLOAD_DIR: z.string().default('uploads'),
  PRIVATE_UPLOAD_DIR: z.string().default('uploads/_private'),
  MAX_UPLOAD_BYTES: z.coerce.number().int().positive().default(5242880),
  PUBLIC_APP_URL: z.string().url().optional(),
  RESEND_API_KEY: z.string().min(8).optional(),
  EMAIL_FROM: z.string().min(3).optional(),
  VOICE_PROVIDER: z.string().optional(),
  VOICE_TOKEN_ENDPOINT: z.string().url().optional(),
  VOICE_API_KEY: z.string().min(8).optional(),
  MOOSYL_SECRET_KEY: z.string().min(8).optional(),
  MOOSYL_WEBHOOK_SECRET: z.string().min(8).optional(),
  MOOSYL_CHECKOUT_ENDPOINT: z.string().url().optional(),
  PASSWORD_RESET_TEST_MODE: z.enum(['true','false']).default('false'),
  SWAGGER_ENABLED: z.enum(['true','false']).optional(),
  TERMS_VERSION: z.string().min(1).max(40).default('v1'),
  SEED_ADMIN_EMAIL: z.string().email().optional(),
  SEED_ADMIN_USERNAME: z.string().optional(),
  SEED_ADMIN_PASSWORD: z.string().min(10).optional(),
});

export function validateEnv(input: Record<string, unknown>) {
  return schema.parse(input);
}
