ALTER TABLE "UploadedFile" ADD COLUMN "isPrivate" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "User" ADD COLUMN "acceptedTermsAt" TIMESTAMP(3), ADD COLUMN "termsVersion" TEXT;

-- MAURITANIA LUDO V8 final product modules: recovery, privacy, KYC, achievements, referrals, support and tournaments.
CREATE TYPE "IdentityVerificationStatus" AS ENUM ('UNVERIFIED','PENDING','VERIFIED','REJECTED');
CREATE TYPE "AchievementMetric" AS ENUM ('MATCHES','WINS','LEVEL','XP');
CREATE TYPE "SupportTicketStatus" AS ENUM ('OPEN','IN_PROGRESS','WAITING_USER','RESOLVED','CLOSED');
CREATE TYPE "TournamentStatus" AS ENUM ('DRAFT','OPEN','ACTIVE','COMPLETED','CANCELLED');
CREATE TYPE "TournamentEntryStatus" AS ENUM ('REGISTERED','ACTIVE','ELIMINATED','WINNER','WITHDRAWN');
CREATE TYPE "TournamentPairingStatus" AS ENUM ('PENDING','READY','ACTIVE','COMPLETED','BYE','CANCELLED');

CREATE TABLE "PasswordResetRequest" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "userId" UUID NOT NULL,
  "codeHash" TEXT NOT NULL,
  "resetTokenHash" TEXT,
  "destination" TEXT,
  "expiresAt" TIMESTAMP(3) NOT NULL,
  "verifiedAt" TIMESTAMP(3),
  "consumedAt" TIMESTAMP(3),
  "attempts" INTEGER NOT NULL DEFAULT 0,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "PasswordResetRequest_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "PasswordResetRequest_userId_createdAt_idx" ON "PasswordResetRequest"("userId","createdAt");
CREATE INDEX "PasswordResetRequest_expiresAt_consumedAt_idx" ON "PasswordResetRequest"("expiresAt","consumedAt");

CREATE TABLE "UserPrivacySetting" (
  "userId" UUID NOT NULL,
  "showOnlineStatus" BOOLEAN NOT NULL DEFAULT true,
  "allowDirectMessages" BOOLEAN NOT NULL DEFAULT true,
  "allowInvites" BOOLEAN NOT NULL DEFAULT true,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "UserPrivacySetting_pkey" PRIMARY KEY ("userId")
);

CREATE TABLE "IdentityVerification" (
  "userId" UUID NOT NULL,
  "status" "IdentityVerificationStatus" NOT NULL DEFAULT 'UNVERIFIED',
  "legalName" TEXT,
  "dateOfBirth" TIMESTAMP(3),
  "countryCode" TEXT,
  "documentFrontFileId" UUID,
  "documentBackFileId" UUID,
  "selfieFileId" UUID,
  "note" TEXT,
  "reviewedBy" UUID,
  "reviewedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "IdentityVerification_pkey" PRIMARY KEY ("userId")
);
CREATE INDEX "IdentityVerification_status_updatedAt_idx" ON "IdentityVerification"("status","updatedAt");
CREATE INDEX "IdentityVerification_documentFrontFileId_idx" ON "IdentityVerification"("documentFrontFileId");
CREATE INDEX "IdentityVerification_documentBackFileId_idx" ON "IdentityVerification"("documentBackFileId");
CREATE INDEX "IdentityVerification_selfieFileId_idx" ON "IdentityVerification"("selfieFileId");
CREATE INDEX "UploadedFile_userId_isPrivate_createdAt_idx" ON "UploadedFile"("userId","isPrivate","createdAt");

CREATE TABLE "AchievementDefinition" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "code" TEXT NOT NULL,
  "titleAr" TEXT NOT NULL,
  "titleEn" TEXT NOT NULL,
  "descriptionAr" TEXT,
  "descriptionEn" TEXT,
  "metric" "AchievementMetric" NOT NULL,
  "target" INTEGER NOT NULL,
  "rewardCoins" INTEGER NOT NULL DEFAULT 0,
  "rewardGems" INTEGER NOT NULL DEFAULT 0,
  "iconUrl" TEXT,
  "sortOrder" INTEGER NOT NULL DEFAULT 0,
  "enabled" BOOLEAN NOT NULL DEFAULT true,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "AchievementDefinition_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "AchievementDefinition_code_key" ON "AchievementDefinition"("code");
CREATE INDEX "AchievementDefinition_enabled_sortOrder_idx" ON "AchievementDefinition"("enabled","sortOrder");

CREATE TABLE "UserAchievement" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "userId" UUID NOT NULL,
  "achievementId" UUID NOT NULL,
  "claimedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "UserAchievement_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "UserAchievement_userId_achievementId_key" ON "UserAchievement"("userId","achievementId");
CREATE INDEX "UserAchievement_userId_claimedAt_idx" ON "UserAchievement"("userId","claimedAt");

CREATE TABLE "ReferralProfile" (
  "userId" UUID NOT NULL,
  "code" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "ReferralProfile_pkey" PRIMARY KEY ("userId")
);
CREATE UNIQUE INDEX "ReferralProfile_code_key" ON "ReferralProfile"("code");

CREATE TABLE "Referral" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "referrerUserId" UUID NOT NULL,
  "referredUserId" UUID NOT NULL,
  "code" TEXT NOT NULL,
  "rewardedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "Referral_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "Referral_referredUserId_key" ON "Referral"("referredUserId");
CREATE INDEX "Referral_referrerUserId_createdAt_idx" ON "Referral"("referrerUserId","createdAt");
CREATE INDEX "Referral_code_idx" ON "Referral"("code");

CREATE TABLE "SupportTicket" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "userId" UUID NOT NULL,
  "subject" TEXT NOT NULL,
  "category" TEXT NOT NULL,
  "priority" INTEGER NOT NULL DEFAULT 2,
  "status" "SupportTicketStatus" NOT NULL DEFAULT 'OPEN',
  "lastMessageAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "SupportTicket_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "SupportTicket_userId_updatedAt_idx" ON "SupportTicket"("userId","updatedAt");
CREATE INDEX "SupportTicket_status_lastMessageAt_idx" ON "SupportTicket"("status","lastMessageAt");

CREATE TABLE "SupportMessage" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "ticketId" UUID NOT NULL,
  "userId" UUID,
  "isStaff" BOOLEAN NOT NULL DEFAULT false,
  "text" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "SupportMessage_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "SupportMessage_ticketId_createdAt_idx" ON "SupportMessage"("ticketId","createdAt");

CREATE TABLE "Tournament" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "code" TEXT NOT NULL,
  "nameAr" TEXT NOT NULL,
  "nameEn" TEXT NOT NULL,
  "descriptionAr" TEXT,
  "descriptionEn" TEXT,
  "imageUrl" TEXT,
  "status" "TournamentStatus" NOT NULL DEFAULT 'DRAFT',
  "ruleCode" TEXT NOT NULL DEFAULT 'CLASSIC',
  "matchPlayers" INTEGER NOT NULL DEFAULT 2,
  "minPlayers" INTEGER NOT NULL DEFAULT 2,
  "maxPlayers" INTEGER NOT NULL DEFAULT 16,
  "entryFee" DECIMAL(20,4) NOT NULL DEFAULT 0,
  "prizePool" DECIMAL(20,4) NOT NULL DEFAULT 0,
  "currency" TEXT NOT NULL DEFAULT 'MRU',
  "registrationOpensAt" TIMESTAMP(3),
  "registrationClosesAt" TIMESTAMP(3),
  "startsAt" TIMESTAMP(3),
  "completedAt" TIMESTAMP(3),
  "sortOrder" INTEGER NOT NULL DEFAULT 0,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "Tournament_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "Tournament_code_key" ON "Tournament"("code");
CREATE INDEX "Tournament_status_startsAt_sortOrder_idx" ON "Tournament"("status","startsAt","sortOrder");

CREATE TABLE "TournamentEntry" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "tournamentId" UUID NOT NULL,
  "userId" UUID NOT NULL,
  "seed" INTEGER,
  "status" "TournamentEntryStatus" NOT NULL DEFAULT 'REGISTERED',
  "placement" INTEGER,
  "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "eliminatedAt" TIMESTAMP(3),
  CONSTRAINT "TournamentEntry_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "TournamentEntry_tournamentId_userId_key" ON "TournamentEntry"("tournamentId","userId");
CREATE INDEX "TournamentEntry_tournamentId_status_seed_idx" ON "TournamentEntry"("tournamentId","status","seed");
CREATE INDEX "TournamentEntry_userId_joinedAt_idx" ON "TournamentEntry"("userId","joinedAt");

CREATE TABLE "TournamentPairing" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "tournamentId" UUID NOT NULL,
  "roundNumber" INTEGER NOT NULL,
  "position" INTEGER NOT NULL,
  "playerAUserId" UUID,
  "playerBUserId" UUID,
  "winnerUserId" UUID,
  "matchId" UUID,
  "status" "TournamentPairingStatus" NOT NULL DEFAULT 'PENDING',
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "TournamentPairing_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "TournamentPairing_tournamentId_roundNumber_position_key" ON "TournamentPairing"("tournamentId","roundNumber","position");
CREATE INDEX "TournamentPairing_tournamentId_roundNumber_status_idx" ON "TournamentPairing"("tournamentId","roundNumber","status");
CREATE INDEX "TournamentPairing_matchId_idx" ON "TournamentPairing"("matchId");

-- Referential integrity for final product modules.
ALTER TABLE "PasswordResetRequest" ADD CONSTRAINT "PasswordResetRequest_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "UserPrivacySetting" ADD CONSTRAINT "UserPrivacySetting_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "IdentityVerification" ADD CONSTRAINT "IdentityVerification_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "IdentityVerification" ADD CONSTRAINT "IdentityVerification_reviewedBy_fkey" FOREIGN KEY ("reviewedBy") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "IdentityVerification" ADD CONSTRAINT "IdentityVerification_documentFrontFileId_fkey" FOREIGN KEY ("documentFrontFileId") REFERENCES "UploadedFile"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "IdentityVerification" ADD CONSTRAINT "IdentityVerification_documentBackFileId_fkey" FOREIGN KEY ("documentBackFileId") REFERENCES "UploadedFile"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "IdentityVerification" ADD CONSTRAINT "IdentityVerification_selfieFileId_fkey" FOREIGN KEY ("selfieFileId") REFERENCES "UploadedFile"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "UserAchievement" ADD CONSTRAINT "UserAchievement_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "UserAchievement" ADD CONSTRAINT "UserAchievement_achievementId_fkey" FOREIGN KEY ("achievementId") REFERENCES "AchievementDefinition"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ReferralProfile" ADD CONSTRAINT "ReferralProfile_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Referral" ADD CONSTRAINT "Referral_referrerUserId_fkey" FOREIGN KEY ("referrerUserId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Referral" ADD CONSTRAINT "Referral_referredUserId_fkey" FOREIGN KEY ("referredUserId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "SupportTicket" ADD CONSTRAINT "SupportTicket_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "SupportMessage" ADD CONSTRAINT "SupportMessage_ticketId_fkey" FOREIGN KEY ("ticketId") REFERENCES "SupportTicket"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "SupportMessage" ADD CONSTRAINT "SupportMessage_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "TournamentEntry" ADD CONSTRAINT "TournamentEntry_tournamentId_fkey" FOREIGN KEY ("tournamentId") REFERENCES "Tournament"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "TournamentEntry" ADD CONSTRAINT "TournamentEntry_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "TournamentPairing" ADD CONSTRAINT "TournamentPairing_tournamentId_fkey" FOREIGN KEY ("tournamentId") REFERENCES "Tournament"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "TournamentPairing" ADD CONSTRAINT "TournamentPairing_playerAUserId_fkey" FOREIGN KEY ("playerAUserId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "TournamentPairing" ADD CONSTRAINT "TournamentPairing_playerBUserId_fkey" FOREIGN KEY ("playerBUserId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "TournamentPairing" ADD CONSTRAINT "TournamentPairing_winnerUserId_fkey" FOREIGN KEY ("winnerUserId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "TournamentPairing" ADD CONSTRAINT "TournamentPairing_matchId_fkey" FOREIGN KEY ("matchId") REFERENCES "Match"("id") ON DELETE SET NULL ON UPDATE CASCADE;
