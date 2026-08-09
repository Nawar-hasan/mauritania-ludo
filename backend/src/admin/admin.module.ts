import { Module } from '@nestjs/common';
import { WalletsModule } from '../wallets/wallets.module.js';
import { AdminController } from './admin.controller.js';
import { AdminContentController } from './admin-content.controller.js';
import { AdminService } from './admin.service.js';
import { AdminContentService } from './admin-content.service.js';
@Module({ imports: [WalletsModule], controllers: [AdminController, AdminContentController], providers: [AdminService, AdminContentService] })
export class AdminModule {}
