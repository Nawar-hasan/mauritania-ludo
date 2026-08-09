CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TYPE "Role" AS ENUM ('PLAYER','SUPPORT','MODERATOR','FINANCE','ADMIN','SUPER_ADMIN');
CREATE TYPE "UserStatus" AS ENUM ('ACTIVE','SUSPENDED','BANNED','DELETED');
CREATE TYPE "WalletType" AS ENUM ('CASH','BONUS','COINS','GEMS','LOCKED');
CREATE TYPE "LedgerDirection" AS ENUM ('CREDIT','DEBIT');
CREATE TYPE "TransactionType" AS ENUM ('DEPOSIT','WITHDRAWAL','ADMIN_ADJUSTMENT','WAGER_LOCK','WAGER_RELEASE','MATCH_PRIZE','PLATFORM_FEE','REFUND','STORE_PURCHASE','REWARD');
CREATE TYPE "TransactionStatus" AS ENUM ('PENDING','PROCESSING','COMPLETED','REJECTED','CANCELLED','REFUNDED');
CREATE TYPE "MatchMode" AS ENUM ('PRACTICE','CASUAL','WAGER','PRIVATE','TOURNAMENT');
CREATE TYPE "MatchStatus" AS ENUM ('WAITING','READY','ACTIVE','COMPLETED','CANCELLED','REFUNDED');
CREATE TYPE "MatchPlayerStatus" AS ENUM ('INVITED','JOINED','READY','ACTIVE','FINISHED','FORFEITED','TIMED_OUT','DISCONNECTED');
CREATE TYPE "MatchEventType" AS ENUM ('MATCH_CREATED','PLAYER_JOINED','PLAYER_READY','MATCH_STARTED','DICE_ROLLED','PIECE_MOVED','PIECE_CAPTURED','PIECE_FINISHED','TURN_TIMED_OUT','PLAYER_RECONNECTED','PLAYER_FORFEITED','MATCH_COMPLETED','MATCH_CANCELLED','WAGER_LOCKED','WAGER_SETTLED','WAGER_REFUNDED');
CREATE TYPE "PlayerColor" AS ENUM ('RED','GREEN','YELLOW','BLUE');
CREATE TYPE "MatchmakingStatus" AS ENUM ('SEARCHING','MATCHED','CANCELLED','EXPIRED');
CREATE TYPE "NotificationType" AS ENUM ('SYSTEM','MATCH','WALLET','TOURNAMENT','SOCIAL');

CREATE TABLE "User" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(), "email" TEXT UNIQUE, "phone" TEXT UNIQUE,
  "username" TEXT NOT NULL UNIQUE, "passwordHash" TEXT NOT NULL, "status" "UserStatus" NOT NULL DEFAULT 'ACTIVE',
  "roles" "Role"[] NOT NULL DEFAULT ARRAY['PLAYER']::"Role"[], "preferredLocale" TEXT NOT NULL DEFAULT 'ar',
  "lastLoginAt" TIMESTAMP(3), "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX "User_status_idx" ON "User"("status"); CREATE INDEX "User_createdAt_idx" ON "User"("createdAt");

CREATE TABLE "UserProfile" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(), "userId" UUID NOT NULL UNIQUE, "displayName" TEXT NOT NULL,
  "avatarUrl" TEXT, "countryCode" TEXT, "bio" TEXT, "level" INTEGER NOT NULL DEFAULT 1, "xp" INTEGER NOT NULL DEFAULT 0,
  "wins" INTEGER NOT NULL DEFAULT 0, "losses" INTEGER NOT NULL DEFAULT 0, "matches" INTEGER NOT NULL DEFAULT 0,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP, "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "UserProfile_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE
);

CREATE TABLE "RefreshSession" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(), "userId" UUID NOT NULL, "tokenHash" TEXT NOT NULL, "deviceId" TEXT,
  "deviceName" TEXT, "ipAddress" TEXT, "userAgent" TEXT, "expiresAt" TIMESTAMP(3) NOT NULL, "revokedAt" TIMESTAMP(3),
  "lastUsedAt" TIMESTAMP(3), "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "RefreshSession_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE
);
CREATE INDEX "RefreshSession_userId_expiresAt_idx" ON "RefreshSession"("userId","expiresAt");

CREATE TABLE "WalletAccount" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(), "userId" UUID NOT NULL, "type" "WalletType" NOT NULL,
  "currency" TEXT NOT NULL DEFAULT 'MRU', "balance" DECIMAL(20,4) NOT NULL DEFAULT 0, "version" INTEGER NOT NULL DEFAULT 0,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP, "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "WalletAccount_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE,
  CONSTRAINT "WalletAccount_userId_type_currency_key" UNIQUE ("userId","type","currency")
);
CREATE INDEX "WalletAccount_userId_idx" ON "WalletAccount"("userId");

CREATE TABLE "FinancialTransaction" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(), "userId" UUID NOT NULL, "type" "TransactionType" NOT NULL,
  "status" "TransactionStatus" NOT NULL DEFAULT 'PENDING', "amount" DECIMAL(20,4) NOT NULL, "fee" DECIMAL(20,4) NOT NULL DEFAULT 0,
  "currency" TEXT NOT NULL DEFAULT 'MRU', "externalRef" TEXT, "idempotencyKey" TEXT UNIQUE, "description" TEXT,
  "metadata" JSONB, "processedAt" TIMESTAMP(3), "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "FinancialTransaction_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT
);
CREATE INDEX "FinancialTransaction_userId_createdAt_idx" ON "FinancialTransaction"("userId","createdAt");
CREATE INDEX "FinancialTransaction_status_createdAt_idx" ON "FinancialTransaction"("status","createdAt");

CREATE TABLE "LedgerEntry" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(), "userId" UUID NOT NULL, "accountId" UUID NOT NULL, "transactionId" UUID,
  "direction" "LedgerDirection" NOT NULL, "amount" DECIMAL(20,4) NOT NULL, "balanceBefore" DECIMAL(20,4) NOT NULL,
  "balanceAfter" DECIMAL(20,4) NOT NULL, "referenceType" TEXT, "referenceId" TEXT, "description" TEXT, "metadata" JSONB,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "LedgerEntry_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT,
  CONSTRAINT "LedgerEntry_accountId_fkey" FOREIGN KEY ("accountId") REFERENCES "WalletAccount"("id") ON DELETE RESTRICT,
  CONSTRAINT "LedgerEntry_transactionId_fkey" FOREIGN KEY ("transactionId") REFERENCES "FinancialTransaction"("id") ON DELETE SET NULL
);
CREATE INDEX "LedgerEntry_userId_createdAt_idx" ON "LedgerEntry"("userId","createdAt");
CREATE INDEX "LedgerEntry_accountId_createdAt_idx" ON "LedgerEntry"("accountId","createdAt");
CREATE INDEX "LedgerEntry_referenceType_referenceId_idx" ON "LedgerEntry"("referenceType","referenceId");

CREATE TABLE "GameRuleSet" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(), "code" TEXT NOT NULL UNIQUE, "name" TEXT NOT NULL,
  "piecesPerPlayer" INTEGER NOT NULL DEFAULT 4, "requiresSixToExit" BOOLEAN NOT NULL DEFAULT true,
  "extraTurnOnSix" BOOLEAN NOT NULL DEFAULT true, "extraTurnOnCapture" BOOLEAN NOT NULL DEFAULT true,
  "extraTurnOnFinish" BOOLEAN NOT NULL DEFAULT false, "threeSixesLoseTurn" BOOLEAN NOT NULL DEFAULT true,
  "exactRollToFinish" BOOLEAN NOT NULL DEFAULT true, "blockadeEnabled" BOOLEAN NOT NULL DEFAULT true,
  "rollSeconds" INTEGER NOT NULL DEFAULT 12, "moveSeconds" INTEGER NOT NULL DEFAULT 15,
  "maxInactiveTurns" INTEGER NOT NULL DEFAULT 3, "reconnectSeconds" INTEGER NOT NULL DEFAULT 30,
  "finishAllPlayers" BOOLEAN NOT NULL DEFAULT false, "enabled" BOOLEAN NOT NULL DEFAULT true,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP, "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE "Match" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(), "publicCode" TEXT NOT NULL UNIQUE, "mode" "MatchMode" NOT NULL,
  "status" "MatchStatus" NOT NULL DEFAULT 'WAITING', "maxPlayers" INTEGER NOT NULL, "stakeAmount" DECIMAL(20,4) NOT NULL DEFAULT 0,
  "currency" TEXT NOT NULL DEFAULT 'MRU', "platformFeeRate" DECIMAL(8,6) NOT NULL DEFAULT 0, "ruleSetId" UUID NOT NULL,
  "currentState" JSONB, "stateVersion" INTEGER NOT NULL DEFAULT 0, "winnerUserId" UUID, "nextActionAt" TIMESTAMP(3),
  "startedAt" TIMESTAMP(3), "completedAt" TIMESTAMP(3), "cancelledAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP, "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "Match_ruleSetId_fkey" FOREIGN KEY ("ruleSetId") REFERENCES "GameRuleSet"("id") ON DELETE RESTRICT
);
CREATE INDEX "Match_status_nextActionAt_idx" ON "Match"("status","nextActionAt");
CREATE INDEX "Match_mode_status_createdAt_idx" ON "Match"("mode","status","createdAt");

CREATE TABLE "MatchPlayer" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(), "matchId" UUID NOT NULL, "userId" UUID NOT NULL, "color" "PlayerColor",
  "seat" INTEGER NOT NULL, "status" "MatchPlayerStatus" NOT NULL DEFAULT 'JOINED', "inactiveTurns" INTEGER NOT NULL DEFAULT 0,
  "finishPosition" INTEGER, "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP, "readyAt" TIMESTAMP(3), "finishedAt" TIMESTAMP(3),
  CONSTRAINT "MatchPlayer_matchId_fkey" FOREIGN KEY ("matchId") REFERENCES "Match"("id") ON DELETE CASCADE,
  CONSTRAINT "MatchPlayer_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT,
  CONSTRAINT "MatchPlayer_matchId_userId_key" UNIQUE ("matchId","userId"),
  CONSTRAINT "MatchPlayer_matchId_seat_key" UNIQUE ("matchId","seat")
);
CREATE INDEX "MatchPlayer_userId_joinedAt_idx" ON "MatchPlayer"("userId","joinedAt");

CREATE TABLE "MatchEvent" (
  "id" BIGSERIAL PRIMARY KEY, "matchId" UUID NOT NULL, "actorUserId" UUID, "type" "MatchEventType" NOT NULL,
  "sequence" INTEGER NOT NULL, "payload" JSONB, "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "MatchEvent_matchId_fkey" FOREIGN KEY ("matchId") REFERENCES "Match"("id") ON DELETE CASCADE,
  CONSTRAINT "MatchEvent_matchId_sequence_key" UNIQUE ("matchId","sequence")
);
CREATE INDEX "MatchEvent_matchId_createdAt_idx" ON "MatchEvent"("matchId","createdAt");

CREATE TABLE "MatchmakingTicket" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(), "userId" UUID NOT NULL, "matchId" UUID, "mode" "MatchMode" NOT NULL,
  "maxPlayers" INTEGER NOT NULL, "stakeAmount" DECIMAL(20,4) NOT NULL DEFAULT 0, "currency" TEXT NOT NULL DEFAULT 'MRU',
  "ruleCode" TEXT NOT NULL, "status" "MatchmakingStatus" NOT NULL DEFAULT 'SEARCHING', "expiresAt" TIMESTAMP(3) NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP, "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "MatchmakingTicket_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE,
  CONSTRAINT "MatchmakingTicket_matchId_fkey" FOREIGN KEY ("matchId") REFERENCES "Match"("id") ON DELETE SET NULL
);
CREATE INDEX "MatchmakingTicket_status_mode_maxPlayers_stakeAmount_ruleCode_idx" ON "MatchmakingTicket"("status","mode","maxPlayers","stakeAmount","ruleCode");
CREATE INDEX "MatchmakingTicket_userId_status_idx" ON "MatchmakingTicket"("userId","status");

CREATE TABLE "AppSetting" (
  "key" TEXT PRIMARY KEY, "value" JSONB NOT NULL, "description" TEXT, "isPublic" BOOLEAN NOT NULL DEFAULT false,
  "updatedBy" UUID, "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP, "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE "Notification" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(), "userId" UUID NOT NULL, "type" "NotificationType" NOT NULL,
  "title" TEXT NOT NULL, "body" TEXT NOT NULL, "data" JSONB, "readAt" TIMESTAMP(3), "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "Notification_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE
);
CREATE INDEX "Notification_userId_readAt_createdAt_idx" ON "Notification"("userId","readAt","createdAt");

CREATE TABLE "UploadedFile" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(), "userId" UUID NOT NULL, "storageKey" TEXT NOT NULL UNIQUE,
  "originalName" TEXT NOT NULL, "mimeType" TEXT NOT NULL, "sizeBytes" INTEGER NOT NULL, "publicUrl" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "UploadedFile_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE
);

CREATE TABLE "AuditLog" (
  "id" BIGSERIAL PRIMARY KEY, "actorUserId" UUID, "action" TEXT NOT NULL, "entityType" TEXT NOT NULL, "entityId" TEXT,
  "before" JSONB, "after" JSONB, "ipAddress" TEXT, "userAgent" TEXT, "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "AuditLog_actorUserId_fkey" FOREIGN KEY ("actorUserId") REFERENCES "User"("id") ON DELETE SET NULL
);
CREATE INDEX "AuditLog_actorUserId_createdAt_idx" ON "AuditLog"("actorUserId","createdAt");
CREATE INDEX "AuditLog_entityType_entityId_idx" ON "AuditLog"("entityType","entityId");
