import { Module } from '@nestjs/common';
import { EngagementController, EngagementAdminController } from './engagement.controller.js';
import { EngagementService } from './engagement.service.js';
@Module({ controllers: [EngagementController, EngagementAdminController], providers: [EngagementService], exports: [EngagementService] })
export class EngagementModule {}
