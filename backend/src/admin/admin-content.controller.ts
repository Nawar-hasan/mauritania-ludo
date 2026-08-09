import { Body, Controller, Delete, Get, Param, Patch, Post, Req } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import type { Request } from 'express';
import { Role } from '../generated/prisma/client.js';
import { CurrentUser } from '../common/decorators/current-user.decorator.js';
import type { AuthUser } from '../common/decorators/current-user.decorator.js';
import { Roles } from '../common/decorators/roles.decorator.js';
import { AdminContentService } from './admin-content.service.js';
import { CreateCatalogItemDto, UpdateCatalogItemDto } from './dto/catalog-item.dto.js';
import { CreateThemeCampaignDto, UpdateThemeCampaignDto } from './dto/theme-campaign.dto.js';
import { CreateLevelDefinitionDto, UpdateLevelDefinitionDto } from './dto/level-definition.dto.js';
import { CreatePaymentMethodDto, UpdatePaymentMethodDto } from './dto/payment-method.dto.js';
import { CreateGameRuleSetDto, UpdateGameRuleSetDto } from './dto/game-rule-set.dto.js';
import { CreateStageDefinitionDto, UpdateStageDefinitionDto } from './dto/stage-definition.dto.js';
import { GrantCatalogItemDto } from './dto/grant-catalog-item.dto.js';

@ApiBearerAuth()
@ApiTags('admin-content')
@Roles(Role.ADMIN, Role.SUPER_ADMIN)
@Controller('admin')
export class AdminContentController {
  constructor(private readonly content: AdminContentService) {}

  @Get('catalog') catalog() { return this.content.catalog(); }
  @Get('users/:userId/inventory') inventory(@Param('userId') userId: string) { return this.content.inventory(userId); }
  @Post('users/:userId/inventory') grantInventory(@CurrentUser() actor: AuthUser, @Req() req: Request, @Param('userId') userId: string, @Body() dto: GrantCatalogItemDto) { return this.content.grantCatalogItem(actor.sub, userId, dto.itemId, dto.quantity ?? 1, dto.equip ?? false, req); }
  @Delete('users/:userId/inventory/:itemId') revokeInventory(@CurrentUser() actor: AuthUser, @Req() req: Request, @Param('userId') userId: string, @Param('itemId') itemId: string) { return this.content.revokeCatalogItem(actor.sub, userId, itemId, req); }
  @Post('catalog') createCatalog(@CurrentUser() actor: AuthUser, @Req() req: Request, @Body() dto: CreateCatalogItemDto) { return this.content.createCatalog(actor.sub, dto, req); }
  @Patch('catalog/:id') updateCatalog(@CurrentUser() actor: AuthUser, @Req() req: Request, @Param('id') id: string, @Body() dto: UpdateCatalogItemDto) { return this.content.updateCatalog(actor.sub, id, dto, req); }
  @Delete('catalog/:id') archiveCatalog(@CurrentUser() actor: AuthUser, @Req() req: Request, @Param('id') id: string) { return this.content.archiveCatalog(actor.sub, id, req); }

  @Get('campaigns') campaigns() { return this.content.campaigns(); }
  @Post('campaigns') createCampaign(@CurrentUser() actor: AuthUser, @Req() req: Request, @Body() dto: CreateThemeCampaignDto) { return this.content.createCampaign(actor.sub, dto, req); }
  @Patch('campaigns/:id') updateCampaign(@CurrentUser() actor: AuthUser, @Req() req: Request, @Param('id') id: string, @Body() dto: UpdateThemeCampaignDto) { return this.content.updateCampaign(actor.sub, id, dto, req); }
  @Delete('campaigns/:id') deleteCampaign(@CurrentUser() actor: AuthUser, @Req() req: Request, @Param('id') id: string) { return this.content.deleteCampaign(actor.sub, id, req); }

  @Get('levels') levels() { return this.content.levels(); }
  @Post('levels') createLevel(@CurrentUser() actor: AuthUser, @Req() req: Request, @Body() dto: CreateLevelDefinitionDto) { return this.content.createLevel(actor.sub, dto, req); }
  @Patch('levels/:level') updateLevel(@CurrentUser() actor: AuthUser, @Req() req: Request, @Param('level') level: string, @Body() dto: UpdateLevelDefinitionDto) { return this.content.updateLevel(actor.sub, Number(level), dto, req); }
  @Delete('levels/:level') deleteLevel(@CurrentUser() actor: AuthUser, @Req() req: Request, @Param('level') level: string) { return this.content.deleteLevel(actor.sub, Number(level), req); }

  @Get('payment-methods') paymentMethods() { return this.content.paymentMethods(); }
  @Get('payment-intents') paymentIntents() { return this.content.paymentIntents(); }
  @Post('payment-methods') createPaymentMethod(@CurrentUser() actor: AuthUser, @Req() req: Request, @Body() dto: CreatePaymentMethodDto) { return this.content.createPaymentMethod(actor.sub, dto, req); }
  @Patch('payment-methods/:id') updatePaymentMethod(@CurrentUser() actor: AuthUser, @Req() req: Request, @Param('id') id: string, @Body() dto: UpdatePaymentMethodDto) { return this.content.updatePaymentMethod(actor.sub, id, dto, req); }

  @Get('stages') stages() { return this.content.stages(); }
  @Post('stages') createStage(@CurrentUser() actor: AuthUser, @Req() req: Request, @Body() dto: CreateStageDefinitionDto) { return this.content.createStage(actor.sub, dto, req); }
  @Patch('stages/:id') updateStage(@CurrentUser() actor: AuthUser, @Req() req: Request, @Param('id') id: string, @Body() dto: UpdateStageDefinitionDto) { return this.content.updateStage(actor.sub, id, dto, req); }
  @Delete('stages/:id') deleteStage(@CurrentUser() actor: AuthUser, @Req() req: Request, @Param('id') id: string) { return this.content.deleteStage(actor.sub, id, req); }

  @Get('game-rules') rules() { return this.content.rules(); }
  @Post('game-rules') createRule(@CurrentUser() actor: AuthUser, @Req() req: Request, @Body() dto: CreateGameRuleSetDto) { return this.content.createRule(actor.sub, dto, req); }
  @Patch('game-rules/:id') updateRule(@CurrentUser() actor: AuthUser, @Req() req: Request, @Param('id') id: string, @Body() dto: UpdateGameRuleSetDto) { return this.content.updateRule(actor.sub, id, dto, req); }
  @Delete('game-rules/:id') disableRule(@CurrentUser() actor: AuthUser, @Req() req: Request, @Param('id') id: string) { return this.content.disableRule(actor.sub, id, req); }
}
