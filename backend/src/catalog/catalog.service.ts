import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import {
  CatalogItemType,
  CatalogStatus,
  InventorySource,
  LedgerDirection,
  Prisma,
  TransactionStatus,
  TransactionType,
  WalletType,
} from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';

@Injectable()
export class CatalogService {
  constructor(private readonly prisma: PrismaService) {}

  async bootstrap(userId?: string) {
    const now = new Date();
    const [items, campaigns, levels, stages, rules, methods, inventory] = await Promise.all([
      this.prisma.catalogItem.findMany({
        where: { status: CatalogStatus.ACTIVE },
        orderBy: [{ isFeatured: 'desc' }, { sortOrder: 'asc' }, { createdAt: 'desc' }],
      }),
      this.prisma.themeCampaign.findMany({
        where: {
          enabled: true,
          AND: [
            { OR: [{ startsAt: null }, { startsAt: { lte: now } }] },
            { OR: [{ endsAt: null }, { endsAt: { gte: now } }] },
          ],
        },
        orderBy: [{ priority: 'desc' }, { createdAt: 'desc' }],
      }),
      this.prisma.levelDefinition.findMany({ where: { enabled: true }, orderBy: { level: 'asc' } }),
      this.prisma.stageDefinition.findMany({ where: { enabled: true }, orderBy: [{ sortOrder: 'asc' }, { minLevel: 'asc' }] }),
      this.prisma.gameRuleSet.findMany({ where: { enabled: true }, orderBy: [{ sortOrder: 'asc' }, { code: 'asc' }] }),
      this.prisma.paymentMethod.findMany({
        where: { status: 'ACTIVE' },
        select: {
          id: true, code: true, provider: true, nameAr: true, nameEn: true, supportsDeposit: true,
          supportsWithdrawal: true, currency: true, minAmount: true, maxAmount: true, feeFixed: true,
          feeRate: true, iconUrl: true, publicConfig: true, sortOrder: true,
        },
        orderBy: { sortOrder: 'asc' },
      }),
      userId ? this.prisma.userInventory.findMany({ where: { userId }, include: { item: true } }) : Promise.resolve([]),
    ]);
    return { items, campaigns, levels, stages, rules, paymentMethods: methods, inventory };
  }

  list(type?: CatalogItemType) {
    return this.prisma.catalogItem.findMany({
      where: { status: CatalogStatus.ACTIVE, ...(type ? { type } : {}) },
      orderBy: [{ isFeatured: 'desc' }, { sortOrder: 'asc' }, { createdAt: 'desc' }],
    });
  }

  inventory(userId: string) {
    return this.prisma.userInventory.findMany({
      where: { userId },
      include: { item: true },
      orderBy: [{ equipped: 'desc' }, { acquiredAt: 'desc' }],
    });
  }

  async purchase(userId: string, itemId: string, quantityInput = 1) {
    const quantity = Math.max(1, Math.min(99, Number(quantityInput || 1)));
    return this.prisma.$transaction(async (tx) => {
      const item = await tx.catalogItem.findUnique({ where: { id: itemId } });
      if (!item || item.status !== CatalogStatus.ACTIVE) throw new NotFoundException('Store item not found');
      if (item.isDefault) throw new BadRequestException('Default items do not need to be purchased');
      if (item.priceWallet === WalletType.LOCKED) throw new BadRequestException('Invalid store wallet');
      const profile = await tx.userProfile.findUnique({ where: { userId } });
      if (!profile) throw new NotFoundException('Player profile not found');
      if (profile.level < item.minLevel) throw new BadRequestException(`Level ${item.minLevel} is required`);

      const existing = await tx.userInventory.findUnique({ where: { userId_itemId: { userId, itemId } } });
      const stackable = item.type === CatalogItemType.SKILL || item.type === CatalogItemType.EMOTE;
      const currencyPack = item.type === CatalogItemType.COIN_PACK || item.type === CatalogItemType.GEM_PACK;
      if (existing && !stackable && !currencyPack) throw new BadRequestException('Item already owned');
      const metadata = (item.metadata && typeof item.metadata === 'object' ? item.metadata : {}) as Record<string, unknown>;
      const grantPerUnit = currencyPack ? Number(metadata.grantAmount ?? metadata.amount ?? 0) : 0;
      if (currencyPack && (!Number.isFinite(grantPerUnit) || grantPerUnit <= 0)) {
        throw new BadRequestException('Currency pack metadata must contain a positive grantAmount');
      }

      const total = item.price.mul(quantity);
      const account = await tx.walletAccount.findUnique({
        where: { userId_type_currency: { userId, type: item.priceWallet, currency: 'MRU' } },
      });
      if (!account) throw new NotFoundException('Wallet account not found');
      if (account.balance.lessThan(total)) throw new BadRequestException('Insufficient balance');

      const after = account.balance.sub(total);
      const transaction = await tx.financialTransaction.create({
        data: {
          userId,
          type: TransactionType.STORE_PURCHASE,
          status: TransactionStatus.COMPLETED,
          amount: total,
          currency: 'MRU',
          description: `Store purchase: ${item.code}`,
          processedAt: new Date(),
          metadata: { itemId: item.id, itemCode: item.code, quantity, walletType: item.priceWallet },
        },
      });
      await tx.walletAccount.update({ where: { id: account.id }, data: { balance: after, version: { increment: 1 } } });
      await tx.ledgerEntry.create({
        data: {
          userId,
          accountId: account.id,
          transactionId: transaction.id,
          direction: LedgerDirection.DEBIT,
          amount: total,
          balanceBefore: account.balance,
          balanceAfter: after,
          referenceType: 'STORE_ITEM',
          referenceId: item.id,
          description: `Purchased ${item.code}`,
        },
      });
      const purchase = await tx.storePurchase.create({
        data: { userId, itemId, transactionId: transaction.id, price: total, walletType: item.priceWallet, quantity },
      });

      if (currencyPack) {
        const targetType = item.type === CatalogItemType.COIN_PACK ? WalletType.COINS : WalletType.GEMS;
        const target = await tx.walletAccount.findUnique({
          where: { userId_type_currency: { userId, type: targetType, currency: 'MRU' } },
        });
        if (!target) throw new NotFoundException('Target wallet account not found');
        const grant = new Prisma.Decimal(grantPerUnit * quantity);
        const targetAfter = target.balance.add(grant);
        const rewardTransaction = await tx.financialTransaction.create({
          data: {
            userId,
            type: TransactionType.REWARD,
            status: TransactionStatus.COMPLETED,
            amount: grant,
            currency: 'MRU',
            description: `${item.type === CatalogItemType.COIN_PACK ? 'Coin' : 'Gem'} pack: ${item.code}`,
            processedAt: new Date(),
            metadata: { catalogItemId: item.id, purchaseId: purchase.id, quantity, grantAmount: grant.toString(), walletType: targetType },
          },
        });
        await tx.walletAccount.update({ where: { id: target.id }, data: { balance: targetAfter, version: { increment: 1 } } });
        await tx.ledgerEntry.create({
          data: {
            userId,
            accountId: target.id,
            transactionId: rewardTransaction.id,
            direction: LedgerDirection.CREDIT,
            amount: grant,
            balanceBefore: target.balance,
            balanceAfter: targetAfter,
            referenceType: 'STORE_PACK',
            referenceId: item.id,
            description: `Granted from ${item.code}`,
          },
        });
        return { item, inventory: null, purchase, transaction, rewardTransaction, granted: { walletType: targetType, amount: grant } };
      }

      const owned = await tx.userInventory.upsert({
        where: { userId_itemId: { userId, itemId } },
        update: { quantity: { increment: quantity } },
        create: { userId, itemId, source: InventorySource.PURCHASE, quantity },
        include: { item: true },
      });
      return { item, inventory: owned, purchase, transaction };
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
  }

  async equip(userId: string, itemId: string) {
    return this.prisma.$transaction(async (tx) => {
      const owned = await tx.userInventory.findUnique({ where: { userId_itemId: { userId, itemId } }, include: { item: true } });
      if (!owned) {
        const item = await tx.catalogItem.findUnique({ where: { id: itemId } });
        if (!item?.isDefault) throw new BadRequestException('Item is not owned');
        await tx.userInventory.create({ data: { userId, itemId, source: InventorySource.DEFAULT, equipped: false } });
      }
      const item = owned?.item ?? await tx.catalogItem.findUnique({ where: { id: itemId } });
      if (!item) throw new NotFoundException('Item not found');
      await tx.userInventory.updateMany({
        where: { userId, equipped: true, item: { type: item.type } },
        data: { equipped: false },
      });
      return tx.userInventory.update({
        where: { userId_itemId: { userId, itemId } },
        data: { equipped: true },
        include: { item: true },
      });
    });
  }
}
