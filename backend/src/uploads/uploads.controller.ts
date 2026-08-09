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
  @UseInterceptors(FileInterceptor('file'))
  uploadAvatar(@CurrentUser() user: AuthUser, @UploadedFile() file: Express.Multer.File) {
    return this.uploads.avatar(user.sub, file);
  }

  @Post('receipt')
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(FileInterceptor('file'))
  uploadReceipt(@CurrentUser() user: AuthUser, @UploadedFile() file: Express.Multer.File) {
    return this.uploads.receipt(user.sub, file);
  }
}
