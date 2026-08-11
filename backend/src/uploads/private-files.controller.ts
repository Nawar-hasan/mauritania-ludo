import { Controller, Get, Param, StreamableFile } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../common/decorators/current-user.decorator.js';
import type { AuthUser } from '../common/decorators/current-user.decorator.js';
import { UploadsService } from './uploads.service.js';

@ApiBearerAuth() @ApiTags('files') @Controller('files')
export class PrivateFilesController {
  constructor(private readonly uploads: UploadsService) {}
  @Get(':id') async get(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    const { file, bytes } = await this.uploads.privateFile(user, id);
    return new StreamableFile(bytes, { type: file.mimeType, disposition: `inline; filename="${file.id}"` });
  }
}
