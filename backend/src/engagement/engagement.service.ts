import { BadRequestException, ConflictException, HttpException, Injectable, NotFoundException } from '@nestjs/common';
import { randomBytes } from 'node:crypto';
import {
  AchievementMetric,
  IdentityVerificationStatus,
  LedgerDirection,
  NotificationType,
  Prisma,
  TransactionStatus,
  TransactionType,
  WalletType,
} from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { RedisService } from '../redis/redis.service.js';
import { ApplyReferralDto, ReviewIdentityDto, SubmitIdentityDto, UpdatePrivacyDto, UpsertAchievementDto } from './dto/engagement.dto.js';

@Injectable()
export class EngagementService {
  constructor(private readonly prisma: PrismaService, private readonly redis: RedisService) {}

  async leaderboard() {
    const profiles = await this.prisma.userProfile.findMany({ orderBy: [{ wins: 'desc' }, { xp: 'desc' }, { matches: 'desc' }], take: 100 });
    const users = profiles.length ? await this.prisma.user.findMany({ where: { id: { in: profiles.map((p) => p.userId) }, status: 'ACTIVE' }, select: { id: true, username: true } }) : [];
    const map = new Map(users.map((u) => [u.id, u]));
    return { items: profiles.filter((p) => map.has(p.userId)).map((p, index) => ({ rank: index + 1, ...p, username: map.get(p.userId)?.username })) };
  }

  async achievements(userId: string) {
    const [profile, definitions, claimed] = await Promise.all([
      this.prisma.userProfile.findUnique({ where: { userId } }),
      this.prisma.achievementDefinition.findMany({ where: { enabled: true }, orderBy: [{ sortOrder: 'asc' }, { target: 'asc' }] }),
      this.prisma.userAchievement.findMany({ where: { userId } }),
    ]);
    if (!profile) throw new NotFoundException('Profile not found');
    const claimedById = new Map(claimed.map((row) => [row.achievementId, row]));
    return {
      items: definitions.map((item) => {
        const progress = this.metricValue(item.metric, profile);
        const record = claimedById.get(item.id);
        return {
          ...item,
          progress,
          target: item.target,
          progressRatio: Math.min(1, progress / Math.max(1, item.target)),
          unlocked: progress >= item.target,
          claimed: Boolean(record?.claimedAt),
          claimedAt: record?.claimedAt ?? null,
        };
      }),
    };
  }

  async claimAchievement(userId: string, id: string) {
    await this.enforceLimit(`achievement:claim:${userId}`, 30, 300);
    return this.prisma.$transaction(async (tx) => {
      const [profile, definition, existing] = await Promise.all([
        tx.userProfile.findUnique({ where: { userId } }),
        tx.achievementDefinition.findUnique({ where: { id } }),
        tx.userAchievement.findUnique({ where: { userId_achievementId: { userId, achievementId: id } } }),
      ]);
      if (!profile || !definition || !definition.enabled) throw new NotFoundException('Achievement not found');
      if (existing?.claimedAt) throw new ConflictException('Achievement reward already claimed');
      if (this.metricValue(definition.metric, profile) < definition.target) throw new BadRequestException('Achievement is not unlocked yet');

      const record = existing
        ? await tx.userAchievement.update({ where: { id: existing.id }, data: { claimedAt: new Date() } })
        : await tx.userAchievement.create({ data: { userId, achievementId: id, claimedAt: new Date() } });

      await this.grantReward(tx, userId, WalletType.COINS, definition.rewardCoins, 'ACHIEVEMENT', id, `Achievement ${definition.code}`);
      await this.grantReward(tx, userId, WalletType.GEMS, definition.rewardGems, 'ACHIEVEMENT', id, `Achievement ${definition.code}`);
      await tx.notification.create({ data: {
        userId,
        type: NotificationType.SYSTEM,
        title: 'Achievement reward claimed',
        body: `${definition.titleEn}: ${definition.rewardCoins} coins, ${definition.rewardGems} gems`,
        data: { achievementId: id },
      } });
      return record;
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
  }

  async referralOverview(userId: string) {
    const profile = await this.ensureReferralProfile(userId);
    const [referrals, rewardCoins] = await Promise.all([
      this.prisma.referral.findMany({ where: { referrerUserId: userId }, orderBy: { createdAt: 'desc' }, take: 100 }),
      this.settingNumber('referral_reward_coins', 100),
    ]);
    const users = referrals.length
      ? await this.prisma.user.findMany({ where: { id: { in: referrals.map((r) => r.referredUserId) } }, select: { id: true, username: true, profile: true } })
      : [];
    const userMap = new Map(users.map((u) => [u.id, u]));
    return {
      code: profile.code,
      rewardCoins,
      invitedCount: referrals.length,
      referrals: referrals.map((r) => ({ ...r, user: userMap.get(r.referredUserId) ?? null })),
      alreadyReferred: Boolean(await this.prisma.referral.findUnique({ where: { referredUserId: userId } })),
    };
  }

  async applyReferral(userId: string, dto: ApplyReferralDto) {
    await this.enforceLimit(`referral:apply:${userId}`, 8, 3600);
    const code = dto.code.trim().toUpperCase();
    return this.prisma.$transaction(async (tx) => {
      const existing = await tx.referral.findUnique({ where: { referredUserId: userId } });
      if (existing) throw new ConflictException('A referral code was already applied');
      const owner = await tx.referralProfile.findUnique({ where: { code } });
      if (!owner) throw new NotFoundException('Referral code not found');
      if (owner.userId === userId) throw new BadRequestException('You cannot use your own referral code');
      const reward = await this.settingNumberTx(tx, 'referral_reward_coins', 100);
      const referral = await tx.referral.create({ data: { referrerUserId: owner.userId, referredUserId: userId, code, rewardedAt: new Date() } });
      await this.grantReward(tx, owner.userId, WalletType.COINS, reward, 'REFERRAL', referral.id, 'Referral reward');
      await this.grantReward(tx, userId, WalletType.COINS, reward, 'REFERRAL', referral.id, 'Referral welcome reward');
      await tx.notification.createMany({ data: [
        { userId: owner.userId, type: NotificationType.SYSTEM, title: 'Friend joined', body: `You received ${reward} coins.`, data: { referralId: referral.id } },
        { userId, type: NotificationType.SYSTEM, title: 'Referral applied', body: `You received ${reward} coins.`, data: { referralId: referral.id } },
      ] });
      return referral;
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
  }

  async privacy(userId: string) {
    return this.prisma.userPrivacySetting.upsert({ where: { userId }, update: {}, create: { userId } });
  }

  async updatePrivacy(userId: string, dto: UpdatePrivacyDto) {
    return this.prisma.userPrivacySetting.upsert({
      where: { userId },
      update: dto,
      create: { userId, ...dto },
    });
  }

  async identity(userId: string) {
    return this.prisma.identityVerification.upsert({
      where: { userId }, update: {}, create: { userId },
      include: {
        documentFront: { select: { id: true, originalName: true } },
        documentBack: { select: { id: true, originalName: true } },
        selfie: { select: { id: true, originalName: true } },
      },
    });
  }

  async submitIdentity(userId: string, dto: SubmitIdentityDto) {
    await this.enforceLimit(`identity:submit:${userId}`, 5, 86400);
    const dob = new Date(dto.dateOfBirth);
    const age = this.ageYears(dob);
    if (!Number.isFinite(dob.getTime()) || age < 18) throw new BadRequestException('You must be at least 18 years old for protected money features');

    const ids = [dto.documentFrontFileId, dto.documentBackFileId, dto.selfieFileId].filter((id): id is string => Boolean(id));
    const files = await this.prisma.uploadedFile.findMany({ where: { id: { in: ids }, userId, isPrivate: true }, select: { id: true, storageKey: true } });
    if (files.length !== new Set(ids).size || files.some((file) => !file.storageKey.startsWith(`identity/${userId}/`))) {
      throw new BadRequestException('Identity documents must be uploaded by this account before submission');
    }

    return this.prisma.identityVerification.upsert({
      where: { userId },
      update: {
        legalName: dto.legalName.trim(), dateOfBirth: dob, countryCode: dto.countryCode.toUpperCase(),
        documentFrontFileId: dto.documentFrontFileId, documentBackFileId: dto.documentBackFileId ?? null, selfieFileId: dto.selfieFileId,
        status: IdentityVerificationStatus.PENDING, note: null, reviewedAt: null, reviewedBy: null,
      },
      create: {
        userId, legalName: dto.legalName.trim(), dateOfBirth: dob, countryCode: dto.countryCode.toUpperCase(),
        documentFrontFileId: dto.documentFrontFileId, documentBackFileId: dto.documentBackFileId ?? null, selfieFileId: dto.selfieFileId,
        status: IdentityVerificationStatus.PENDING,
      },
      include: {
        documentFront: { select: { id: true, originalName: true } },
        documentBack: { select: { id: true, originalName: true } },
        selfie: { select: { id: true, originalName: true } },
      },
    });
  }

  identityQueue() {
    return this.prisma.identityVerification.findMany({
      where: { status: { in: [IdentityVerificationStatus.PENDING, IdentityVerificationStatus.REJECTED] } },
      include: {
        user: { select: { username: true, email: true, phone: true } },
        documentFront: { select: { id: true, originalName: true, publicUrl: true, mimeType: true, sizeBytes: true } },
        documentBack: { select: { id: true, originalName: true, publicUrl: true, mimeType: true, sizeBytes: true } },
        selfie: { select: { id: true, originalName: true, publicUrl: true, mimeType: true, sizeBytes: true } },
      },
      orderBy: { updatedAt: 'desc' }, take: 100,
    });
  }

  async reviewIdentity(
    userId: string,
    reviewerId: string,
    dto: ReviewIdentityDto,
    requestMeta?: { ipAddress?: string; userAgent?: string },
  ) {
    const current = await this.prisma.identityVerification.findUnique({ where: { userId } });
    if (!current) throw new NotFoundException('Identity verification record not found');
    if (dto.status === 'VERIFIED' && (!current.documentFrontFileId || !current.selfieFileId)) {
      throw new BadRequestException('A front identity document and selfie are required before verification');
    }

    const nextStatus = dto.status as IdentityVerificationStatus;
    return this.prisma.$transaction(async (tx) => {
      const updated = await tx.identityVerification.update({
        where: { userId },
        data: {
          status: nextStatus,
          note: dto.note?.trim() || null,
          reviewedBy: reviewerId,
          reviewedAt: new Date(),
        },
      });
      await tx.auditLog.create({
        data: {
          actorUserId: reviewerId,
          action: 'IDENTITY_REVIEWED',
          entityType: 'IdentityVerification',
          entityId: userId,
          before: { status: current.status, hadFrontDocument: Boolean(current.documentFrontFileId), hadSelfie: Boolean(current.selfieFileId) },
          after: { status: updated.status, hadFrontDocument: Boolean(updated.documentFrontFileId), hadSelfie: Boolean(updated.selfieFileId) },
          ipAddress: requestMeta?.ipAddress,
          userAgent: requestMeta?.userAgent,
        },
      });
      return updated;
    });
  }

  achievementDefinitions() { return this.prisma.achievementDefinition.findMany({ orderBy: [{ sortOrder: 'asc' }, { target: 'asc' }] }); }
  upsertAchievement(id: string | null, dto: UpsertAchievementDto) {
    const data = { ...dto, metric: dto.metric as AchievementMetric, rewardCoins: dto.rewardCoins ?? 0, rewardGems: dto.rewardGems ?? 0, sortOrder: dto.sortOrder ?? 0, enabled: dto.enabled ?? true };
    return id
      ? this.prisma.achievementDefinition.update({ where: { id }, data })
      : this.prisma.achievementDefinition.create({ data });
  }

  private metricValue(metric: AchievementMetric, profile: { matches: number; wins: number; level: number; xp: number }) {
    switch (metric) {
      case AchievementMetric.MATCHES: return profile.matches;
      case AchievementMetric.WINS: return profile.wins;
      case AchievementMetric.LEVEL: return profile.level;
      case AchievementMetric.XP: return profile.xp;
    }
  }

  private async ensureReferralProfile(userId: string) {
    const existing = await this.prisma.referralProfile.findUnique({ where: { userId } });
    if (existing) return existing;
    for (let i = 0; i < 8; i++) {
      const code = `ML-${randomBytes(4).toString('hex').toUpperCase()}`;
      try { return await this.prisma.referralProfile.create({ data: { userId, code } }); }
      catch { /* retry on unique collision */ }
    }
    throw new ConflictException('Unable to allocate referral code');
  }

  private async grantReward(tx: Prisma.TransactionClient, userId: string, type: WalletType, rawAmount: number, referenceType: string, referenceId: string, description: string) {
    const amount = Number(rawAmount ?? 0);
    if (!Number.isFinite(amount) || amount <= 0) return;
    const idempotencyKey = `${referenceType}:${referenceId}:${userId}:${type}`;
    const already = await tx.financialTransaction.findUnique({ where: { idempotencyKey } });
    if (already) return;
    const account = await tx.walletAccount.findUnique({ where: { userId_type_currency: { userId, type, currency: 'MRU' } } });
    if (!account) throw new NotFoundException('Reward wallet not found');
    const value = new Prisma.Decimal(amount);
    const after = account.balance.add(value);
    const transaction = await tx.financialTransaction.create({ data: {
      userId, type: TransactionType.REWARD, status: TransactionStatus.COMPLETED, amount: value, currency: 'MRU', idempotencyKey, description, processedAt: new Date(), metadata: { referenceType, referenceId, walletType: type },
    } });
    await tx.walletAccount.update({ where: { id: account.id }, data: { balance: after, version: { increment: 1 } } });
    await tx.ledgerEntry.create({ data: { userId, accountId: account.id, transactionId: transaction.id, direction: LedgerDirection.CREDIT, amount: value, balanceBefore: account.balance, balanceAfter: after, referenceType, referenceId, description } });
  }

  private async settingNumber(key: string, fallback: number) {
    const row = await this.prisma.appSetting.findUnique({ where: { key } });
    return typeof row?.value === 'number' ? row.value : fallback;
  }
  private async settingNumberTx(tx: Prisma.TransactionClient, key: string, fallback: number) {
    const row = await tx.appSetting.findUnique({ where: { key } });
    return typeof row?.value === 'number' ? row.value : fallback;
  }
  private ageYears(dob: Date) {
    const today = new Date();
    let age = today.getUTCFullYear() - dob.getUTCFullYear();
    const month = today.getUTCMonth() - dob.getUTCMonth();
    if (month < 0 || (month === 0 && today.getUTCDate() < dob.getUTCDate())) age--;
    return age;
  }

  private async enforceLimit(key: string, limit: number, seconds: number) {
    const result = await this.redis.rateLimit(key, limit, seconds);
    if (!result.allowed) throw new HttpException(`Too many requests. Try again in ${result.retryAfter} seconds.`, 429);
  }
}
