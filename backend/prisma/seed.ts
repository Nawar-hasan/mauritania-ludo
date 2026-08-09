import 'dotenv/config';
import argon2 from 'argon2';
import { PrismaPg } from '@prisma/adapter-pg';
import { CatalogItemType, CatalogRarity, CatalogStatus, CampaignSurface, PaymentMethodStatus, PaymentProvider, PrismaClient, Role, WalletType } from '../src/generated/prisma/client.js';

const connectionString = process.env.DATABASE_URL;
if (!connectionString) throw new Error('DATABASE_URL is required');
const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString }) });

async function main() {
  const overwriteDefaults = process.env.SEED_OVERWRITE_DEFAULTS === 'true';
  const resetAdminPassword = process.env.SEED_RESET_ADMIN_PASSWORD === 'true';
  const rules = [
    { code: 'CLASSIC', name: 'Classic', descriptionAr: 'أربع قطع وقواعد لودو الأساسية المحمية من لوحة التحكم.', descriptionEn: 'Four pieces with the protected canonical Ludo rules.', sortOrder: 1, rollSeconds: 12, moveSeconds: 15, piecesPerPlayer: 4, requiresSixToExit: true, extraTurnOnSix: true, extraTurnOnCapture: true, extraTurnOnFinish: false, threeSixesLoseTurn: true, exactRollToFinish: true, blockadeEnabled: true, finishAllPlayers: false, enabled: true },
    { code: 'QUICK', name: 'Quick', descriptionAr: 'قطعتان لكل لاعب ومؤقت أقصر للمباريات السريعة.', descriptionEn: 'Two pieces per player and shorter timers for faster matches.', sortOrder: 2, rollSeconds: 10, moveSeconds: 12, piecesPerPlayer: 2 },
    { code: 'MASTER', name: 'Master', descriptionAr: 'أربع قطع ومؤقت صارم والحواجز وعقوبة ثلاث ستات.', descriptionEn: 'Four pieces, strict timers, blockades and the three-sixes penalty.', sortOrder: 3, rollSeconds: 10, moveSeconds: 12, piecesPerPlayer: 4 },
  ];
  for (const rule of rules) {
    await prisma.gameRuleSet.upsert({ where: { code: rule.code }, update: overwriteDefaults ? rule : {}, create: rule });
  }

  const settings = [
    ['platform_fee_rate', 0.05, 'Default wager platform fee rate', true],
    ['minimum_wager', 50, 'Minimum wager amount', true],
    ['maximum_wager', 100000, 'Maximum wager amount', true],
    ['real_money_enabled', false, 'Must remain false until compliance approval', true],
    ['maintenance_mode', false, 'Blocks new matches when enabled', true],
    ['minimum_withdrawal', 300, 'Minimum withdrawal request amount', true],
    ['maximum_withdrawal', 100000, 'Maximum withdrawal request amount', true],
    ['deposit_account', '', 'Administration transfer account shown in the mobile application', true],
    ['deposit_instructions', '', 'Transfer instructions shown before receipt submission', true],
    ['support_email', '', 'Public support email configured by administration', true],
  ] as const;
  for (const [key, value, description, isPublic] of settings) {
    await prisma.appSetting.upsert({ where: { key }, update: overwriteDefaults ? { value, description, isPublic } : {}, create: { key, value, description, isPublic } });
  }


  const levels = [
    { level: 1, xpRequired: 0, titleAr: 'مبتدئ', titleEn: 'Beginner', rewards: { coins: 100 } },
    { level: 2, xpRequired: 150, titleAr: 'لاعب واعد', titleEn: 'Rising Player', rewards: { coins: 150 } },
    { level: 3, xpRequired: 400, titleAr: 'منافس', titleEn: 'Competitor', rewards: { gems: 5 } },
    { level: 4, xpRequired: 800, titleAr: 'محترف', titleEn: 'Professional', rewards: { coins: 300 } },
    { level: 5, xpRequired: 1500, titleAr: 'بطل', titleEn: 'Champion', rewards: { gems: 15 } },
  ];
  for (const level of levels) {
    await prisma.levelDefinition.upsert({ where: { level: level.level }, update: overwriteDefaults ? level : {}, create: level });
  }


  const stages = [
    { code: 'BRONZE', nameAr: 'المرحلة البرونزية', nameEn: 'Bronze Stage', minLevel: 1, maxLevel: 4, colorHex: '#CD7F32', rewards: { coins: 100 }, sortOrder: 1 },
    { code: 'SILVER', nameAr: 'المرحلة الفضية', nameEn: 'Silver Stage', minLevel: 5, maxLevel: 9, colorHex: '#C0C0C0', rewards: { coins: 500, gems: 10 }, sortOrder: 2 },
    { code: 'GOLD', nameAr: 'المرحلة الذهبية', nameEn: 'Gold Stage', minLevel: 10, maxLevel: 19, colorHex: '#FFD54F', rewards: { coins: 1000, gems: 25, itemCodes: ['DICE_GOLD'] }, sortOrder: 3 },
    { code: 'CHAMPION', nameAr: 'مرحلة الأبطال', nameEn: 'Champion Stage', minLevel: 20, maxLevel: null, colorHex: '#9C6BFF', rewards: { coins: 2500, gems: 50, itemCodes: ['BOARD_ROYAL'] }, sortOrder: 4 },
  ];
  for (const stage of stages) {
    await prisma.stageDefinition.upsert({ where: { code: stage.code }, update: overwriteDefaults ? stage : {}, create: stage });
  }

  const catalog = [
    { code: 'BOARD_CLASSIC', type: CatalogItemType.BOARD, nameAr: 'الرقعة الكلاسيكية', nameEn: 'Classic Board', price: 0, priceWallet: WalletType.COINS, isDefault: true, status: CatalogStatus.ACTIVE, rarity: CatalogRarity.COMMON, sortOrder: 1, metadata: { renderMode: 'PALETTE', backgroundColor: '#F2F0E8', trackColor: '#F6F6F6', gridColor: '#616161', safeColor: '#777777', glowColor: '#FFD54F' } },
    { code: 'DICE_CLASSIC', type: CatalogItemType.DICE, nameAr: 'النرد الكلاسيكي', nameEn: 'Classic Dice', price: 0, priceWallet: WalletType.COINS, isDefault: true, status: CatalogStatus.ACTIVE, rarity: CatalogRarity.COMMON, sortOrder: 1, metadata: { faceColor: '#FFFFFF', pipColor: '#120A20', borderColor: '#FFD54F', radius: 15 } },
    { code: 'FRAME_CLASSIC', type: CatalogItemType.DICE_FRAME, nameAr: 'إطار النرد الكلاسيكي', nameEn: 'Classic Dice Frame', price: 0, priceWallet: WalletType.COINS, isDefault: true, status: CatalogStatus.ACTIVE, rarity: CatalogRarity.COMMON, sortOrder: 1, metadata: { frameColor: '#FFD54F', glowColor: '#FFD54F', borderWidth: 3 } },
    { code: 'BOARD_ROYAL', type: CatalogItemType.BOARD, nameAr: 'الرقعة الملكية', nameEn: 'Royal Board', price: 750, priceWallet: WalletType.COINS, isDefault: false, status: CatalogStatus.ACTIVE, rarity: CatalogRarity.EPIC, isFeatured: true, sortOrder: 2, metadata: { renderMode: 'PALETTE', backgroundColor: '#FFF4CF', trackColor: '#FFFDF5', gridColor: '#6A431C', safeColor: '#8B5A2B', glowColor: '#FFD54F' } },
    { code: 'DICE_GOLD', type: CatalogItemType.DICE, nameAr: 'النرد الذهبي', nameEn: 'Golden Dice', price: 25, priceWallet: WalletType.GEMS, isDefault: false, status: CatalogStatus.ACTIVE, rarity: CatalogRarity.LEGENDARY, isFeatured: true, sortOrder: 2, metadata: { faceColor: '#FFD54F', pipColor: '#3B2200', borderColor: '#FFF1A8', radius: 16 } },
    { code: 'FRAME_NEON', type: CatalogItemType.DICE_FRAME, nameAr: 'إطار نيون', nameEn: 'Neon Frame', price: 450, priceWallet: WalletType.COINS, isDefault: false, status: CatalogStatus.ACTIVE, rarity: CatalogRarity.RARE, sortOrder: 2, metadata: { frameColor: '#5AE7FF', glowColor: '#9C6BFF', borderWidth: 4 } },
    { code: 'BACKGROUND_PURPLE', type: CatalogItemType.BACKGROUND, nameAr: 'الخلفية البنفسجية', nameEn: 'Purple Background', price: 300, priceWallet: WalletType.COINS, isDefault: false, status: CatalogStatus.ACTIVE, rarity: CatalogRarity.RARE, sortOrder: 1 },
  ];
  for (const item of catalog) {
    await prisma.catalogItem.upsert({ where: { code: item.code }, update: overwriteDefaults ? item : {}, create: item });
  }

  await prisma.themeCampaign.upsert({
    where: { code: 'DEFAULT_BACKGROUND' },
    update: {},
    create: { code: 'DEFAULT_BACKGROUND', surface: CampaignSurface.APP_BACKGROUND, nameAr: 'الخلفية الأساسية', nameEn: 'Default Background', backgroundColor: '#0D0618', enabled: true, priority: 0 },
  });

  const paymentMethods = [
    { code: 'BANKILY_MANUAL', provider: PaymentProvider.MANUAL, nameAr: 'بانكيلي - تحويل يدوي', nameEn: 'Bankily - Manual Transfer', status: PaymentMethodStatus.ACTIVE, supportsDeposit: true, supportsWithdrawal: true, minAmount: 100, maxAmount: 100000, publicConfig: { accountNumber: '', instructionsAr: 'حوّل المبلغ ثم ارفع الإيصال.', instructionsEn: 'Transfer the amount, then upload the receipt.' }, sortOrder: 1 },
    { code: 'SEDAD_MANUAL', provider: PaymentProvider.MANUAL, nameAr: 'السداد - تحويل يدوي', nameEn: 'Sedad - Manual Transfer', status: PaymentMethodStatus.ACTIVE, supportsDeposit: true, supportsWithdrawal: true, minAmount: 100, maxAmount: 100000, publicConfig: { accountNumber: '', instructionsAr: 'حوّل المبلغ ثم ارفع الإيصال.', instructionsEn: 'Transfer the amount, then upload the receipt.' }, sortOrder: 2 },
    { code: 'MOOSYL', provider: PaymentProvider.MOOSYL, nameAr: 'دفع إلكتروني', nameEn: 'Online Payment', status: PaymentMethodStatus.INACTIVE, supportsDeposit: true, supportsWithdrawal: false, minAmount: 100, maxAmount: 100000, secretEnvPrefix: 'MOOSYL', publicConfig: { supportedApps: ['Bankily','Sedad','Masrivi'] }, sortOrder: 3 },
  ];
  for (const method of paymentMethods) {
    await prisma.paymentMethod.upsert({ where: { code: method.code }, update: overwriteDefaults ? method : {}, create: method });
  }

  const email = process.env.SEED_ADMIN_EMAIL;
  const username = process.env.SEED_ADMIN_USERNAME;
  const password = process.env.SEED_ADMIN_PASSWORD;
  if (email && username && password) {
    const passwordHash = await argon2.hash(password);
    const admin = await prisma.user.upsert({
      where: { username },
      update: { email, roles: [Role.SUPER_ADMIN, Role.ADMIN, Role.FINANCE, Role.MODERATOR], ...(resetAdminPassword ? { passwordHash } : {}) },
      create: {
        email, username, passwordHash,
        roles: [Role.SUPER_ADMIN, Role.ADMIN, Role.FINANCE, Role.MODERATOR],
        profile: { create: { displayName: 'Super Administrator' } },
      },
    });
    for (const type of Object.values(WalletType)) {
      await prisma.walletAccount.upsert({
        where: { userId_type_currency: { userId: admin.id, type, currency: 'MRU' } },
        update: {}, create: { userId: admin.id, type, currency: 'MRU' },
      });
    }
    console.log(`Administrator ready: ${admin.username}`);
  } else {
    console.log('Admin seed skipped. Set SEED_ADMIN_EMAIL, SEED_ADMIN_USERNAME and SEED_ADMIN_PASSWORD.');
  }
}

main().finally(() => prisma.$disconnect());
