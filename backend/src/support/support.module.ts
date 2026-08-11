import { Module } from '@nestjs/common';
import { SupportController, SupportAdminController } from './support.controller.js';
import { SupportService } from './support.service.js';
@Module({ controllers: [SupportController, SupportAdminController], providers: [SupportService] })
export class SupportModule {}
