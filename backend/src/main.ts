import 'reflect-metadata';
import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';
import { join } from 'node:path';
import type { NestExpressApplication } from '@nestjs/platform-express';
import type { Request, Response } from 'express';
import { AppModule } from './app.module.js';

async function bootstrap() {
  (BigInt.prototype as unknown as { toJSON: () => string }).toJSON = function () { return this.toString(); };

  console.log('[bootstrap] Creating Nest application...');
  const app = await NestFactory.create<NestExpressApplication>(AppModule, { cors: false, rawBody: true });
  app.set('trust proxy', 1);
  app.setGlobalPrefix('api/v1');
  app.use(helmet({
    crossOriginResourcePolicy: { policy: 'cross-origin' },
    contentSecurityPolicy: false,
  }));
  const allowedOrigins = (process.env.CORS_ORIGINS ?? '').split(',').map((x) => x.trim()).filter(Boolean);
  app.enableCors({
    origin: allowedOrigins,
    credentials: true,
    methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'Idempotency-Key'],
  });
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true, stopAtFirstError: false }));

  const uploadDir = process.env.UPLOAD_DIR ?? join(process.cwd(), 'uploads');
  // Private evidence is stored on the same persistent volume but is never exposed by static hosting.
  app.use('/uploads/_private', (_req: Request, res: Response) => res.sendStatus(404));
  app.useStaticAssets(uploadDir, { prefix: '/uploads/', immutable: true, maxAge: '7d' });

  const swaggerEnabled = process.env.SWAGGER_ENABLED === 'true' || (process.env.NODE_ENV !== 'production' && process.env.SWAGGER_ENABLED !== 'false');
  if (swaggerEnabled) {
    const swagger = new DocumentBuilder()
      .setTitle('MAURITANIA LUDO API')
      .setDescription('Authoritative API for accounts, wallets, matches, tournaments, social, support, engagement, payments and administration')
      .setVersion('1.0.0')
      .addBearerAuth()
      .build();
    SwaggerModule.setup('docs', app, SwaggerModule.createDocument(app, swagger));
  }

  const port = Number(process.env.PORT ?? 3000);
  console.log(`[bootstrap] Listening on 0.0.0.0:${port} ...`);
  await app.listen(port, '0.0.0.0');
  console.log(`Ludo API listening on ${port}`);
}

bootstrap().catch((error) => {
  console.error('[bootstrap] Fatal startup error:', error);
  process.exit(1);
});
