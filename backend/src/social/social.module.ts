import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module.js';
import { SocialController } from './social.controller.js';
import { SocialService } from './social.service.js';
@Module({ imports: [PrismaModule], controllers: [SocialController], providers: [SocialService] })
export class SocialModule {}
