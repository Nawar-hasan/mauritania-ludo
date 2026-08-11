-- MAURITANIA LUDO social rooms and chat
CREATE TYPE "SocialRoomType" AS ENUM ('TEXT', 'VOICE');
CREATE TYPE "SocialRoomVisibility" AS ENUM ('PUBLIC', 'PRIVATE');
CREATE TYPE "SocialRoomMemberRole" AS ENUM ('HOST', 'MODERATOR', 'MEMBER');

CREATE TABLE "SocialRoom" (
  "id" UUID NOT NULL,
  "name" TEXT NOT NULL,
  "description" TEXT,
  "type" "SocialRoomType" NOT NULL DEFAULT 'TEXT',
  "visibility" "SocialRoomVisibility" NOT NULL DEFAULT 'PUBLIC',
  "ownerUserId" UUID NOT NULL,
  "maxParticipants" INTEGER NOT NULL DEFAULT 12,
  "active" BOOLEAN NOT NULL DEFAULT true,
  "voiceProviderRoom" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "SocialRoom_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "SocialRoomMember" (
  "id" UUID NOT NULL,
  "roomId" UUID NOT NULL,
  "userId" UUID NOT NULL,
  "role" "SocialRoomMemberRole" NOT NULL DEFAULT 'MEMBER',
  "muted" BOOLEAN NOT NULL DEFAULT false,
  "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "SocialRoomMember_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "SocialMessage" (
  "id" UUID NOT NULL,
  "roomId" UUID NOT NULL,
  "userId" UUID NOT NULL,
  "text" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "SocialMessage_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "SocialRoom_active_type_createdAt_idx" ON "SocialRoom"("active", "type", "createdAt");
CREATE INDEX "SocialRoom_ownerUserId_createdAt_idx" ON "SocialRoom"("ownerUserId", "createdAt");
CREATE UNIQUE INDEX "SocialRoomMember_roomId_userId_key" ON "SocialRoomMember"("roomId", "userId");
CREATE INDEX "SocialRoomMember_userId_joinedAt_idx" ON "SocialRoomMember"("userId", "joinedAt");
CREATE INDEX "SocialMessage_roomId_createdAt_idx" ON "SocialMessage"("roomId", "createdAt");
CREATE INDEX "SocialMessage_userId_createdAt_idx" ON "SocialMessage"("userId", "createdAt");

ALTER TABLE "SocialRoom" ADD CONSTRAINT "SocialRoom_ownerUserId_fkey" FOREIGN KEY ("ownerUserId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "SocialRoomMember" ADD CONSTRAINT "SocialRoomMember_roomId_fkey" FOREIGN KEY ("roomId") REFERENCES "SocialRoom"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "SocialRoomMember" ADD CONSTRAINT "SocialRoomMember_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "SocialMessage" ADD CONSTRAINT "SocialMessage_roomId_fkey" FOREIGN KEY ("roomId") REFERENCES "SocialRoom"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "SocialMessage" ADD CONSTRAINT "SocialMessage_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
