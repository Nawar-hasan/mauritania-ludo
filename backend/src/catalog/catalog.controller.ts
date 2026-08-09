import { Body, Controller, Get, Param, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { CatalogItemType } from '../generated/prisma/client.js';
import { CurrentUser } from '../common/decorators/current-user.decorator.js';
import type { AuthUser } from '../common/decorators/current-user.decorator.js';
import { Public } from '../common/decorators/public.decorator.js';
import { CatalogService } from './catalog.service.js';
import { PurchaseItemDto } from './dto/purchase-item.dto.js';

@ApiTags('catalog')
@Controller('catalog')
export class CatalogController {
  constructor(private readonly catalog: CatalogService) {}

  @Public()
  @Get('public')
  publicBootstrap() { return this.catalog.bootstrap(); }

  @ApiBearerAuth()
  @Get('bootstrap')
  bootstrap(@CurrentUser() user: AuthUser) { return this.catalog.bootstrap(user.sub); }

  @Public()
  @Get('items')
  items(@Query('type') type?: CatalogItemType) { return this.catalog.list(type); }

  @ApiBearerAuth()
  @Get('inventory')
  inventory(@CurrentUser() user: AuthUser) { return this.catalog.inventory(user.sub); }

  @ApiBearerAuth()
  @Post('items/:id/purchase')
  purchase(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() dto: PurchaseItemDto) {
    return this.catalog.purchase(user.sub, id, dto.quantity);
  }

  @ApiBearerAuth()
  @Post('items/:id/equip')
  equip(@CurrentUser() user: AuthUser, @Param('id') id: string) { return this.catalog.equip(user.sub, id); }
}
