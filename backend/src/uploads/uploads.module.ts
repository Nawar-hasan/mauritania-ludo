import { Module } from '@nestjs/common';
import { UploadsController } from './uploads.controller.js';
import { PrivateFilesController } from './private-files.controller.js';
import { AdminUploadsController } from './admin-uploads.controller.js';
import { UploadsService } from './uploads.service.js';
@Module({ controllers: [UploadsController, PrivateFilesController, AdminUploadsController], providers: [UploadsService] })
export class UploadsModule {}
