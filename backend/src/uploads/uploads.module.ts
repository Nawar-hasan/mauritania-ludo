import { Module } from '@nestjs/common';
import { UploadsController } from './uploads.controller.js';
import { AdminUploadsController } from './admin-uploads.controller.js';
import { UploadsService } from './uploads.service.js';
@Module({ controllers: [UploadsController, AdminUploadsController], providers: [UploadsService] })
export class UploadsModule {}
