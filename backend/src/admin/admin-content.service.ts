import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import type { Request } from 'express';
import { CatalogStatus, InventorySource, Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { CreateCatalogItemDto, UpdateCatalogItemDto } from './dto/catalog-item.dto.js';
import { CreateThemeCampaignDto, UpdateThemeCampaignDto } from './dto/theme-campaign.dto.js';
import { CreateLevelDefinitionDto, UpdateLevelDefinitionDto } from './dto/level-definition.dto.js';
import { CreatePaymentMethodDto, UpdatePaymentMethodDto } from './dto/payment-method.dto.js';
import { CreateGameRuleSetDto, UpdateGameRuleSetDto } from './dto/game-rule-set.dto.js';
import { CreateStageDefinitionDto, UpdateStageDefinitionDto } from './dto/stage-definition.dto.js';

@Injectable()
export class AdminContentService {
  constructor(private readonly prisma: PrismaService) {}

  catalog() { return this.prisma.catalogItem.findMany({ orderBy: [{ type: 'asc' }, { sortOrder: 'asc' }, { createdAt: 'desc' }] }); }
  inventory(userId: string) {
    return this.prisma.userInventory.findMany({ where: { userId }, include: { item: true }, orderBy: [{ equipped: 'desc' }, { acquiredAt: 'desc' }] });
  }
  async grantCatalogItem(actorUserId: string, userId: string, itemId: string, quantityInput: number, equip: boolean, req: Request) {
    const [user, item] = await Promise.all([
      this.prisma.user.findUnique({ where: { id: userId }, select: { id: true } }),
      this.prisma.catalogItem.findUnique({ where: { id: itemId } }),
    ]);
    if (!user) throw new NotFoundException('User not found');
    if (!item) throw new NotFoundException('Catalog item not found');
    const quantity = Math.max(1, Math.min(9999, Number(quantityInput || 1)));
    const granted = await this.prisma.$transaction(async (tx) => {
      if (equip) {
        await tx.userInventory.updateMany({ where: { userId, equipped: true, item: { type: item.type } }, data: { equipped: false } });
      }
      return tx.userInventory.upsert({
        where: { userId_itemId: { userId, itemId } },
        update: { quantity: { increment: quantity }, ...(equip ? { equipped: true } : {}) },
        create: { userId, itemId, quantity, equipped: equip, source: InventorySource.ADMIN_GRANT },
        include: { item: true },
      });
    });
    await this.audit(actorUserId, 'CATALOG_ITEM_GRANTED', 'UserInventory', granted.id, null, { userId, itemId, quantity, equip }, req);
    return granted;
  }
  async revokeCatalogItem(actorUserId: string, userId: string, itemId: string, req: Request) {
    const before = await this.prisma.userInventory.findUnique({ where: { userId_itemId: { userId, itemId } }, include: { item: true } });
    if (!before) throw new NotFoundException('Inventory item not found');
    await this.prisma.userInventory.delete({ where: { userId_itemId: { userId, itemId } } });
    await this.audit(actorUserId, 'CATALOG_ITEM_REVOKED', 'UserInventory', before.id, before, null, req);
    return { deleted: true };
  }
  async createCatalog(actorUserId: string, dto: CreateCatalogItemDto, req: Request) {
    const created = await this.prisma.$transaction(async (tx) => {
      if (dto.isDefault) await tx.catalogItem.updateMany({ where: { type: dto.type, isDefault: true }, data: { isDefault: false } });
      return tx.catalogItem.create({ data: this.catalogData(dto) as Prisma.CatalogItemUncheckedCreateInput });
    });
    await this.audit(actorUserId, 'CATALOG_ITEM_CREATED', 'CatalogItem', created.id, null, created, req);
    return created;
  }
  async updateCatalog(actorUserId: string, id: string, dto: UpdateCatalogItemDto, req: Request) {
    const before = await this.prisma.catalogItem.findUnique({ where: { id } });
    if (!before) throw new NotFoundException('Catalog item not found');
    const after = await this.prisma.$transaction(async (tx) => {
      if (dto.isDefault) await tx.catalogItem.updateMany({ where: { id: { not: id }, type: dto.type ?? before.type, isDefault: true }, data: { isDefault: false } });
      return tx.catalogItem.update({ where: { id }, data: this.catalogData(dto) as Prisma.CatalogItemUpdateInput });
    });
    await this.audit(actorUserId, 'CATALOG_ITEM_UPDATED', 'CatalogItem', id, before, after, req);
    return after;
  }
  async archiveCatalog(actorUserId: string, id: string, req: Request) {
    const before = await this.prisma.catalogItem.findUnique({ where: { id } });
    if (!before) throw new NotFoundException('Catalog item not found');
    const after = await this.prisma.catalogItem.update({ where: { id }, data: { status: CatalogStatus.ARCHIVED } });
    await this.audit(actorUserId, 'CATALOG_ITEM_ARCHIVED', 'CatalogItem', id, before, after, req);
    return after;
  }

  campaigns() { return this.prisma.themeCampaign.findMany({ orderBy: [{ surface: 'asc' }, { priority: 'desc' }, { createdAt: 'desc' }] }); }
  async createCampaign(actorUserId: string, dto: CreateThemeCampaignDto, req: Request) {
    const created = await this.prisma.themeCampaign.create({ data: this.campaignData(dto) as Prisma.ThemeCampaignUncheckedCreateInput });
    await this.audit(actorUserId, 'THEME_CAMPAIGN_CREATED', 'ThemeCampaign', created.id, null, created, req);
    return created;
  }
  async updateCampaign(actorUserId: string, id: string, dto: UpdateThemeCampaignDto, req: Request) {
    const before = await this.prisma.themeCampaign.findUnique({ where: { id } });
    if (!before) throw new NotFoundException('Theme campaign not found');
    const after = await this.prisma.themeCampaign.update({ where: { id }, data: this.campaignData(dto) as Prisma.ThemeCampaignUpdateInput });
    await this.audit(actorUserId, 'THEME_CAMPAIGN_UPDATED', 'ThemeCampaign', id, before, after, req);
    return after;
  }
  async deleteCampaign(actorUserId: string, id: string, req: Request) {
    const before = await this.prisma.themeCampaign.findUnique({ where: { id } });
    if (!before) throw new NotFoundException('Theme campaign not found');
    await this.prisma.themeCampaign.delete({ where: { id } });
    await this.audit(actorUserId, 'THEME_CAMPAIGN_DELETED', 'ThemeCampaign', id, before, null, req);
    return { deleted: true };
  }

  levels() { return this.prisma.levelDefinition.findMany({ orderBy: { level: 'asc' } }); }
  async createLevel(actorUserId: string, dto: CreateLevelDefinitionDto, req: Request) {
    const created = await this.prisma.levelDefinition.create({ data: { ...dto, rewards: dto.rewards as Prisma.InputJsonValue | undefined } });
    await this.audit(actorUserId, 'LEVEL_CREATED', 'LevelDefinition', String(created.level), null, created, req);
    return created;
  }
  async updateLevel(actorUserId: string, level: number, dto: UpdateLevelDefinitionDto, req: Request) {
    const before = await this.prisma.levelDefinition.findUnique({ where: { level } });
    if (!before) throw new NotFoundException('Level not found');
    const { level: ignored, ...rest } = dto;
    const after = await this.prisma.levelDefinition.update({ where: { level }, data: { ...rest, rewards: rest.rewards as Prisma.InputJsonValue | undefined } });
    await this.audit(actorUserId, 'LEVEL_UPDATED', 'LevelDefinition', String(level), before, after, req);
    return after;
  }
  async deleteLevel(actorUserId: string, level: number, req: Request) {
    const before = await this.prisma.levelDefinition.findUnique({ where: { level } });
    if (!before) throw new NotFoundException('Level not found');
    await this.prisma.levelDefinition.delete({ where: { level } });
    await this.audit(actorUserId, 'LEVEL_DELETED', 'LevelDefinition', String(level), before, null, req);
    return { deleted: true };
  }

  paymentMethods() { return this.prisma.paymentMethod.findMany({ orderBy: { sortOrder: 'asc' } }); }
  paymentIntents() { return this.prisma.paymentIntent.findMany({ include: { method: true, user: { select: { username: true, profile: true } } }, orderBy: { createdAt: 'desc' }, take: 100 }); }
  async createPaymentMethod(actorUserId: string, dto: CreatePaymentMethodDto, req: Request) {
    const created = await this.prisma.paymentMethod.create({ data: this.paymentData(dto) as Prisma.PaymentMethodUncheckedCreateInput });
    await this.audit(actorUserId, 'PAYMENT_METHOD_CREATED', 'PaymentMethod', created.id, null, created, req);
    return created;
  }
  async updatePaymentMethod(actorUserId: string, id: string, dto: UpdatePaymentMethodDto, req: Request) {
    const before = await this.prisma.paymentMethod.findUnique({ where: { id } });
    if (!before) throw new NotFoundException('Payment method not found');
    const after = await this.prisma.paymentMethod.update({ where: { id }, data: this.paymentData(dto) as Prisma.PaymentMethodUpdateInput });
    await this.audit(actorUserId, 'PAYMENT_METHOD_UPDATED', 'PaymentMethod', id, before, after, req);
    return after;
  }


  stages() { return this.prisma.stageDefinition.findMany({ orderBy: [{ sortOrder: 'asc' }, { minLevel: 'asc' }] }); }
  async createStage(actorUserId: string, dto: CreateStageDefinitionDto, req: Request) {
    const created = await this.prisma.stageDefinition.create({ data: { ...dto, rewards: dto.rewards as Prisma.InputJsonValue | undefined } });
    await this.audit(actorUserId, 'STAGE_CREATED', 'StageDefinition', created.id, null, created, req);
    return created;
  }
  async updateStage(actorUserId: string, id: string, dto: UpdateStageDefinitionDto, req: Request) {
    const before = await this.prisma.stageDefinition.findUnique({ where: { id } });
    if (!before) throw new NotFoundException('Stage not found');
    const after = await this.prisma.stageDefinition.update({ where: { id }, data: { ...dto, rewards: dto.rewards as Prisma.InputJsonValue | undefined } });
    await this.audit(actorUserId, 'STAGE_UPDATED', 'StageDefinition', id, before, after, req);
    return after;
  }
  async deleteStage(actorUserId: string, id: string, req: Request) {
    const before = await this.prisma.stageDefinition.findUnique({ where: { id } });
    if (!before) throw new NotFoundException('Stage not found');
    const after = await this.prisma.stageDefinition.update({ where: { id }, data: { enabled: false } });
    await this.audit(actorUserId, 'STAGE_DISABLED', 'StageDefinition', id, before, after, req);
    return after;
  }

  rules() { return this.prisma.gameRuleSet.findMany({ orderBy: [{ sortOrder: 'asc' }, { code: 'asc' }] }); }

  /**
   * CLASSIC is the canonical ruleset used as the baseline for the real-money capable game flow.
   * Administration may change presentation/order and operational timers, but cannot turn the
   * canonical Ludo mechanics off from the dashboard.
   */
  private protectCoreRules<T extends CreateGameRuleSetDto | UpdateGameRuleSetDto>(code: string, dto: T): T {
    if (code !== 'CLASSIC') return dto;
    return {
      ...dto,
      code: 'CLASSIC',
      piecesPerPlayer: 4,
      requiresSixToExit: true,
      extraTurnOnSix: true,
      extraTurnOnCapture: true,
      extraTurnOnFinish: false,
      threeSixesLoseTurn: true,
      exactRollToFinish: true,
      blockadeEnabled: true,
      finishAllPlayers: false,
      enabled: true,
    } as T;
  }

  async createRule(actorUserId: string, dto: CreateGameRuleSetDto, req: Request) {
    if (dto.code === 'CLASSIC') throw new BadRequestException('CLASSIC is a protected core rule set and already exists');
    const created = await this.prisma.gameRuleSet.create({ data: dto });
    await this.audit(actorUserId, 'GAME_RULE_CREATED', 'GameRuleSet', created.id, null, created, req);
    return created;
  }
  async updateRule(actorUserId: string, id: string, dto: UpdateGameRuleSetDto, req: Request) {
    const before = await this.prisma.gameRuleSet.findUnique({ where: { id } });
    if (!before) throw new NotFoundException('Rule set not found');
    if (dto.code && dto.code !== before.code) throw new BadRequestException('The game rule code cannot be changed after creation');
    const protectedDto = this.protectCoreRules(before.code, dto);
    const after = await this.prisma.gameRuleSet.update({ where: { id }, data: protectedDto });
    await this.audit(actorUserId, 'GAME_RULE_UPDATED', 'GameRuleSet', id, before, after, req);
    return after;
  }
  async disableRule(actorUserId: string, id: string, req: Request) {
    const before = await this.prisma.gameRuleSet.findUnique({ where: { id } });
    if (!before) throw new NotFoundException('Rule set not found');
    if (before.code === 'CLASSIC') throw new BadRequestException('CLASSIC is the protected baseline mode and cannot be disabled');
    const after = await this.prisma.gameRuleSet.update({ where: { id }, data: { enabled: false } });
    await this.audit(actorUserId, 'GAME_RULE_DISABLED', 'GameRuleSet', id, before, after, req);
    return after;
  }

  private catalogData(dto: CreateCatalogItemDto | UpdateCatalogItemDto): Prisma.CatalogItemUncheckedCreateInput | Prisma.CatalogItemUpdateInput {
    return { ...dto, metadata: dto.metadata as Prisma.InputJsonValue | undefined } as any;
  }
  private campaignData(dto: CreateThemeCampaignDto | UpdateThemeCampaignDto): Prisma.ThemeCampaignUncheckedCreateInput | Prisma.ThemeCampaignUpdateInput {
    return {
      ...dto,
      startsAt: dto.startsAt ? new Date(dto.startsAt) : dto.startsAt === undefined ? undefined : null,
      endsAt: dto.endsAt ? new Date(dto.endsAt) : dto.endsAt === undefined ? undefined : null,
      metadata: dto.metadata as Prisma.InputJsonValue | undefined,
    } as any;
  }
  private paymentData(dto: CreatePaymentMethodDto | UpdatePaymentMethodDto): Prisma.PaymentMethodUncheckedCreateInput | Prisma.PaymentMethodUpdateInput {
    return { ...dto, publicConfig: dto.publicConfig as Prisma.InputJsonValue | undefined } as any;
  }
  private audit(actorUserId: string, action: string, entityType: string, entityId: string, before: any, after: any, req: Request) {
    const json = (value: any) => value == null ? undefined : JSON.parse(JSON.stringify(value));
    return this.prisma.auditLog.create({ data: { actorUserId, action, entityType, entityId, before: json(before), after: json(after), ipAddress: req.ip, userAgent: req.headers['user-agent'] } });
  }
}
