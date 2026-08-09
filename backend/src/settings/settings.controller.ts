import { Controller, Get } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Public } from '../common/decorators/public.decorator.js';
import { PrismaService } from '../prisma/prisma.service.js';

@ApiTags('settings')
@Controller('settings')
export class SettingsController {
  constructor(private readonly prisma: PrismaService) {}

  @Public()
  @Get('public')
  async publicSettings() {
    const rows = await this.prisma.appSetting.findMany({ where: { isPublic: true }, orderBy: { key: 'asc' } });
    return Object.fromEntries(rows.map((row) => [row.key, row.value]));
  }
}
