CREATE TYPE "CatalogItemType" AS ENUM ('BOARD','DICE','DICE_FRAME','BACKGROUND','AVATAR_FRAME','EMOTE','SKILL','COIN_PACK','GEM_PACK');
CREATE TYPE "CatalogRarity" AS ENUM ('COMMON','RARE','EPIC','LEGENDARY','LIMITED');
CREATE TYPE "CatalogStatus" AS ENUM ('DRAFT','ACTIVE','ARCHIVED');
CREATE TYPE "InventorySource" AS ENUM ('PURCHASE','REWARD','ADMIN_GRANT','DEFAULT');
CREATE TYPE "CampaignSurface" AS ENUM ('APP_BACKGROUND','HOME_BANNER','STORE_BANNER','GAME_LOBBY');
CREATE TYPE "PaymentProvider" AS ENUM ('MANUAL','MOOSYL','CUSTOM');
CREATE TYPE "PaymentMethodStatus" AS ENUM ('ACTIVE','INACTIVE');
CREATE TYPE "PaymentIntentStatus" AS ENUM ('CREATED','PENDING','SUCCEEDED','FAILED','EXPIRED','CANCELLED');

ALTER TABLE "GameRuleSet"
  ADD COLUMN "descriptionAr" TEXT,
  ADD COLUMN "descriptionEn" TEXT,
  ADD COLUMN "sortOrder" INTEGER NOT NULL DEFAULT 0;

CREATE TABLE "CatalogItem" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "code" TEXT NOT NULL,
  "type" "CatalogItemType" NOT NULL,
  "nameAr" TEXT NOT NULL,
  "nameEn" TEXT NOT NULL,
  "descriptionAr" TEXT,
  "descriptionEn" TEXT,
  "imageUrl" TEXT,
  "previewUrl" TEXT,
  "price" DECIMAL(20,4) NOT NULL DEFAULT 0,
  "priceWallet" "WalletType" NOT NULL DEFAULT 'COINS',
  "minLevel" INTEGER NOT NULL DEFAULT 1,
  "rarity" "CatalogRarity" NOT NULL DEFAULT 'COMMON',
  "status" "CatalogStatus" NOT NULL DEFAULT 'DRAFT',
  "isFeatured" BOOLEAN NOT NULL DEFAULT false,
  "isDefault" BOOLEAN NOT NULL DEFAULT false,
  "sortOrder" INTEGER NOT NULL DEFAULT 0,
  "metadata" JSONB,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "CatalogItem_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "CatalogItem_code_key" ON "CatalogItem"("code");
CREATE INDEX "CatalogItem_type_status_sortOrder_idx" ON "CatalogItem"("type","status","sortOrder");
CREATE INDEX "CatalogItem_isFeatured_status_idx" ON "CatalogItem"("isFeatured","status");

CREATE TABLE "UserInventory" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "userId" UUID NOT NULL,
  "itemId" UUID NOT NULL,
  "source" "InventorySource" NOT NULL,
  "quantity" INTEGER NOT NULL DEFAULT 1,
  "equipped" BOOLEAN NOT NULL DEFAULT false,
  "acquiredAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "UserInventory_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "UserInventory_userId_itemId_key" ON "UserInventory"("userId","itemId");
CREATE INDEX "UserInventory_userId_equipped_idx" ON "UserInventory"("userId","equipped");

CREATE TABLE "StorePurchase" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "userId" UUID NOT NULL,
  "itemId" UUID NOT NULL,
  "transactionId" UUID,
  "price" DECIMAL(20,4) NOT NULL,
  "walletType" "WalletType" NOT NULL,
  "quantity" INTEGER NOT NULL DEFAULT 1,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "StorePurchase_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "StorePurchase_userId_createdAt_idx" ON "StorePurchase"("userId","createdAt");
CREATE INDEX "StorePurchase_itemId_createdAt_idx" ON "StorePurchase"("itemId","createdAt");

CREATE TABLE "LevelDefinition" (
  "level" INTEGER NOT NULL,
  "xpRequired" INTEGER NOT NULL,
  "titleAr" TEXT NOT NULL,
  "titleEn" TEXT NOT NULL,
  "badgeUrl" TEXT,
  "rewards" JSONB,
  "enabled" BOOLEAN NOT NULL DEFAULT true,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "LevelDefinition_pkey" PRIMARY KEY ("level")
);

CREATE TABLE "StageDefinition" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "code" TEXT NOT NULL,
  "nameAr" TEXT NOT NULL,
  "nameEn" TEXT NOT NULL,
  "minLevel" INTEGER NOT NULL,
  "maxLevel" INTEGER,
  "imageUrl" TEXT,
  "colorHex" TEXT,
  "rewards" JSONB,
  "enabled" BOOLEAN NOT NULL DEFAULT true,
  "sortOrder" INTEGER NOT NULL DEFAULT 0,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "StageDefinition_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "StageDefinition_code_key" ON "StageDefinition"("code");
CREATE INDEX "StageDefinition_enabled_sortOrder_minLevel_idx" ON "StageDefinition"("enabled","sortOrder","minLevel");

CREATE TABLE "ThemeCampaign" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "code" TEXT NOT NULL,
  "surface" "CampaignSurface" NOT NULL,
  "nameAr" TEXT NOT NULL,
  "nameEn" TEXT NOT NULL,
  "imageUrl" TEXT,
  "backgroundColor" TEXT,
  "textColor" TEXT,
  "actionType" TEXT,
  "actionValue" TEXT,
  "startsAt" TIMESTAMP(3),
  "endsAt" TIMESTAMP(3),
  "enabled" BOOLEAN NOT NULL DEFAULT true,
  "priority" INTEGER NOT NULL DEFAULT 0,
  "metadata" JSONB,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "ThemeCampaign_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "ThemeCampaign_code_key" ON "ThemeCampaign"("code");
CREATE INDEX "ThemeCampaign_surface_enabled_priority_idx" ON "ThemeCampaign"("surface","enabled","priority");
CREATE INDEX "ThemeCampaign_startsAt_endsAt_idx" ON "ThemeCampaign"("startsAt","endsAt");

CREATE TABLE "PaymentMethod" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "code" TEXT NOT NULL,
  "provider" "PaymentProvider" NOT NULL,
  "nameAr" TEXT NOT NULL,
  "nameEn" TEXT NOT NULL,
  "status" "PaymentMethodStatus" NOT NULL DEFAULT 'INACTIVE',
  "supportsDeposit" BOOLEAN NOT NULL DEFAULT true,
  "supportsWithdrawal" BOOLEAN NOT NULL DEFAULT false,
  "currency" TEXT NOT NULL DEFAULT 'MRU',
  "minAmount" DECIMAL(20,4) NOT NULL DEFAULT 0,
  "maxAmount" DECIMAL(20,4) NOT NULL DEFAULT 100000,
  "feeFixed" DECIMAL(20,4) NOT NULL DEFAULT 0,
  "feeRate" DECIMAL(8,6) NOT NULL DEFAULT 0,
  "iconUrl" TEXT,
  "publicConfig" JSONB,
  "secretEnvPrefix" TEXT,
  "sortOrder" INTEGER NOT NULL DEFAULT 0,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "PaymentMethod_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "PaymentMethod_code_key" ON "PaymentMethod"("code");
CREATE INDEX "PaymentMethod_status_supportsDeposit_sortOrder_idx" ON "PaymentMethod"("status","supportsDeposit","sortOrder");

CREATE TABLE "PaymentIntent" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "userId" UUID NOT NULL,
  "methodId" UUID NOT NULL,
  "transactionId" UUID,
  "providerRef" TEXT,
  "status" "PaymentIntentStatus" NOT NULL DEFAULT 'CREATED',
  "amount" DECIMAL(20,4) NOT NULL,
  "fee" DECIMAL(20,4) NOT NULL DEFAULT 0,
  "currency" TEXT NOT NULL DEFAULT 'MRU',
  "checkoutUrl" TEXT,
  "metadata" JSONB,
  "expiresAt" TIMESTAMP(3),
  "completedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "PaymentIntent_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "PaymentIntent_userId_createdAt_idx" ON "PaymentIntent"("userId","createdAt");
CREATE INDEX "PaymentIntent_status_createdAt_idx" ON "PaymentIntent"("status","createdAt");
CREATE INDEX "PaymentIntent_providerRef_idx" ON "PaymentIntent"("providerRef");

ALTER TABLE "UserInventory" ADD CONSTRAINT "UserInventory_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "UserInventory" ADD CONSTRAINT "UserInventory_itemId_fkey" FOREIGN KEY ("itemId") REFERENCES "CatalogItem"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "StorePurchase" ADD CONSTRAINT "StorePurchase_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "StorePurchase" ADD CONSTRAINT "StorePurchase_itemId_fkey" FOREIGN KEY ("itemId") REFERENCES "CatalogItem"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "PaymentIntent" ADD CONSTRAINT "PaymentIntent_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "PaymentIntent" ADD CONSTRAINT "PaymentIntent_methodId_fkey" FOREIGN KEY ("methodId") REFERENCES "PaymentMethod"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
