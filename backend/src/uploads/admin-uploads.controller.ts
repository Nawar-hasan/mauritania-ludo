import { Controller, Post, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiConsumes, ApiTags } from '@nestjs/swagger';
import { Role } from '../generated/prisma/client.js';
import { CurrentUser } from '../common/decorators/current-user.decorator.js';
import type { AuthUser } from '../common/decorators/current-user.decorator.js';
import { Roles } from '../common/decorators/roles.decorator.js';
import { UploadsService } from './uploads.service.js';

@ApiBearerAuth() @ApiTags('admin-uploads') @Roles(Role.ADMIN, Role.SUPER_ADMIN)
@Controller('admin/uploads')
export class AdminUploadsController {
  constructor(private readonly uploads: UploadsService) {}
  @Post('assets') @ApiConsumes('multipart/form-data') @UseInterceptors(FileInterceptor('file', { limits: { files: 1, fileSize: Number(process.env.MAX_UPLOAD_BYTES ?? 5_242_880) } }))
  asset(@CurrentUser() user: AuthUser, @UploadedFile() file: Express.Multer.File) { return this.uploads.asset(user.sub, file); }
}
