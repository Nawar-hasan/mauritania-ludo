import { Controller, Post, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiConsumes, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../common/decorators/current-user.decorator.js';
import type { AuthUser } from '../common/decorators/current-user.decorator.js';
import { UploadsService } from './uploads.service.js';

@ApiBearerAuth()
@ApiTags('uploads')
@Controller('users/me')
export class UploadsController {
  constructor(private readonly uploads: UploadsService) {}

  @Post('avatar')
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(FileInterceptor('file', { limits: { files: 1, fileSize: Number(process.env.MAX_UPLOAD_BYTES ?? 5_242_880) } }))
  uploadAvatar(@CurrentUser() user: AuthUser, @UploadedFile() file: Express.Multer.File) {
    return this.uploads.avatar(user.sub, file);
  }

  @Post('receipt')
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(FileInterceptor('file', { limits: { files: 1, fileSize: Number(process.env.MAX_UPLOAD_BYTES ?? 5_242_880) } }))
  uploadReceipt(@CurrentUser() user: AuthUser, @UploadedFile() file: Express.Multer.File) {
    return this.uploads.receipt(user.sub, file);
  }

  @Post('identity-document')
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(FileInterceptor('file', { limits: { files: 1, fileSize: Number(process.env.MAX_UPLOAD_BYTES ?? 5_242_880) } }))
  uploadIdentityDocument(@CurrentUser() user: AuthUser, @UploadedFile() file: Express.Multer.File) {
    return this.uploads.identityDocument(user.sub, file);
  }
}
