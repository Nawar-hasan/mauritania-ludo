import { ConflictException, HttpException, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import type { Request } from 'express';
import argon2 from 'argon2';
import { randomBytes, randomInt, randomUUID } from 'node:crypto';
import { PrismaService } from '../prisma/prisma.service.js';
import { RedisService } from '../redis/redis.service.js';
import { Role, UserStatus, WalletType } from '../generated/prisma/client.js';
import { RegisterDto } from './dto/register.dto.js';
import { LoginDto } from './dto/login.dto.js';
import { CompletePasswordResetDto, RequestPasswordResetDto, VerifyPasswordResetDto } from './dto/password-recovery.dto.js';

@Injectable()
export class AuthService {
  constructor(private readonly prisma: PrismaService, private readonly jwt: JwtService, private readonly redis: RedisService) {}

  async register(dto: RegisterDto, req: Request) {
    await this.enforceLimit(`register:${this.ip(req)}`, 8, 3600);
    if (!dto.acceptedTerms) throw new ConflictException('Terms and age confirmation are required');
    if (!dto.email) throw new ConflictException('A valid email address is required for account recovery');
    const exists = await this.prisma.user.findFirst({ where: { OR: [{ username: dto.username }, ...(dto.email ? [{ email: dto.email }] : []), ...(dto.phone ? [{ phone: dto.phone }] : [])] } });
    if (exists) throw new ConflictException('Username, email or phone already exists');
    const passwordHash = await argon2.hash(dto.password);
    const user = await this.prisma.$transaction(async (tx) => {
      const created = await tx.user.create({ data: {
        username: dto.username, email: dto.email?.toLowerCase(), phone: dto.phone, passwordHash,
        preferredLocale: dto.locale ?? 'ar', roles: [Role.PLAYER],
        acceptedTermsAt: new Date(), termsVersion: process.env.TERMS_VERSION ?? 'v1',
        profile: { create: { displayName: dto.displayName } },
      }, include: { profile: true } });
      await tx.walletAccount.createMany({ data: Object.values(WalletType).map((type) => ({ userId: created.id, type, currency: 'MRU' })) });
      await tx.userPrivacySetting.create({ data: { userId: created.id } });
      await tx.identityVerification.create({ data: { userId: created.id } });
      return created;
    });
    return this.issueTokens(user, req, undefined, undefined);
  }

  async login(dto: LoginDto, req: Request) {
    const limitKey = `login:${this.ip(req)}:${dto.identifier.trim().toLowerCase()}`;
    await this.enforceLimit(limitKey, 10, 15 * 60);
    const user = await this.prisma.user.findFirst({ where: { OR: [{ username: dto.identifier }, { email: dto.identifier.toLowerCase() }, { phone: dto.identifier }] }, include: { profile: true } });
    if (!user || !(await argon2.verify(user.passwordHash, dto.password))) throw new UnauthorizedException('Invalid credentials');
    if (user.status !== UserStatus.ACTIVE) throw new UnauthorizedException(`Account is ${user.status.toLowerCase()}`);
    await this.redis.clearRateLimit(limitKey);
    await this.prisma.user.update({ where: { id: user.id }, data: { lastLoginAt: new Date() } });
    return this.issueTokens(user, req, dto.deviceId, dto.deviceName);
  }

  async refresh(rawToken: string, req: Request) {
    let payload: { sub: string; sessionId: string };
    try { payload = await this.jwt.verifyAsync(rawToken, { secret: process.env.JWT_REFRESH_SECRET! }); }
    catch { throw new UnauthorizedException('Invalid refresh token'); }
    const session = await this.prisma.refreshSession.findUnique({ where: { id: payload.sessionId }, include: { user: { include: { profile: true } } } });
    if (!session || session.revokedAt || session.expiresAt <= new Date() || !(await argon2.verify(session.tokenHash, rawToken))) throw new UnauthorizedException('Refresh session is invalid');
    if (session.user.status !== UserStatus.ACTIVE) throw new UnauthorizedException('Account is not active');
    const rotated = await this.prisma.refreshSession.updateMany({
      where: { id: session.id, revokedAt: null, expiresAt: { gt: new Date() } },
      data: { revokedAt: new Date(), lastUsedAt: new Date() },
    });
    if (rotated.count !== 1) throw new UnauthorizedException('Refresh session is invalid');
    return this.issueTokens(session.user, req, session.deviceId ?? undefined, session.deviceName ?? undefined);
  }

  async logout(sessionId: string) {
    await this.prisma.refreshSession.updateMany({ where: { id: sessionId, revokedAt: null }, data: { revokedAt: new Date() } });
  }

  async requestPasswordReset(dto: RequestPasswordResetDto, req: Request) {
    await this.enforceLimit(`password-reset:${this.ip(req)}`, 6, 3600);
    const identifier = dto.identifier.trim();
    const fakeRequestId = randomUUID();
    const deliveryConfigured = Boolean(process.env.RESEND_API_KEY && process.env.EMAIL_FROM);
    const user = await this.prisma.user.findFirst({ where: { OR: [{ username: identifier }, { email: identifier.toLowerCase() }, { phone: identifier }] } });
    if (!user || !user.email) return { accepted: true, requestId: fakeRequestId, deliveryConfigured };

    const code = String(randomInt(100000, 1000000));
    const codeHash = await argon2.hash(code);
    await this.prisma.passwordResetRequest.updateMany({ where: { userId: user.id, consumedAt: null }, data: { consumedAt: new Date() } });
    const request = await this.prisma.passwordResetRequest.create({ data: {
      userId: user.id,
      codeHash,
      destination: this.maskEmail(user.email),
      expiresAt: new Date(Date.now() + 10 * 60 * 1000),
    } });

    await this.sendRecoveryEmail(user.email, code);
    const testMode = process.env.NODE_ENV !== 'production' && process.env.PASSWORD_RESET_TEST_MODE === 'true';
    // Keep the public response uniform so this endpoint cannot be used to enumerate accounts.
    return { accepted: true, requestId: request.id, deliveryConfigured, ...(testMode ? { testCode: code } : {}) };
  }

  async verifyPasswordReset(dto: VerifyPasswordResetDto, req: Request) {
    await this.enforceLimit(`password-verify:${this.ip(req)}:${dto.requestId}`, 8, 15 * 60);
    const request = await this.prisma.passwordResetRequest.findUnique({ where: { id: dto.requestId } });
    if (!request || request.consumedAt || request.expiresAt <= new Date() || request.attempts >= 5) throw new UnauthorizedException('Verification code is invalid or expired');
    const valid = await argon2.verify(request.codeHash, dto.code);
    if (!valid) {
      await this.prisma.passwordResetRequest.update({ where: { id: request.id }, data: { attempts: { increment: 1 } } });
      throw new UnauthorizedException('Verification code is invalid or expired');
    }
    const resetToken = randomBytes(32).toString('base64url');
    await this.prisma.passwordResetRequest.update({ where: { id: request.id }, data: { verifiedAt: new Date(), resetTokenHash: await argon2.hash(resetToken) } });
    return { requestId: request.id, resetToken, expiresIn: Math.max(1, Math.floor((request.expiresAt.getTime() - Date.now()) / 1000)) };
  }

  async completePasswordReset(dto: CompletePasswordResetDto, req: Request) {
    await this.enforceLimit(`password-complete:${this.ip(req)}:${dto.requestId}`, 6, 15 * 60);
    const request = await this.prisma.passwordResetRequest.findUnique({ where: { id: dto.requestId } });
    if (!request || request.consumedAt || !request.verifiedAt || !request.resetTokenHash || request.expiresAt <= new Date()) throw new UnauthorizedException('Reset session is invalid or expired');
    if (!(await argon2.verify(request.resetTokenHash, dto.resetToken))) throw new UnauthorizedException('Reset session is invalid or expired');
    const passwordHash = await argon2.hash(dto.newPassword);
    await this.prisma.$transaction(async (tx) => {
      const claimed = await tx.passwordResetRequest.updateMany({
        where: { id: request.id, consumedAt: null, verifiedAt: { not: null }, expiresAt: { gt: new Date() } },
        data: { consumedAt: new Date() },
      });
      if (claimed.count !== 1) throw new UnauthorizedException('Reset session is invalid or expired');
      await tx.user.update({ where: { id: request.userId }, data: { passwordHash } });
      await tx.refreshSession.updateMany({ where: { userId: request.userId, revokedAt: null }, data: { revokedAt: new Date() } });
    }, { isolationLevel: 'Serializable' });
    return { changed: true };
  }

  private async issueTokens(user: any, req: Request, deviceId?: string, deviceName?: string) {
    const sessionId = randomUUID();
    const base = { sub: user.id, username: user.username, roles: user.roles, sessionId };
    const accessTtl = Number(process.env.JWT_ACCESS_TTL_SECONDS ?? 900);
    const refreshTtl = Number(process.env.JWT_REFRESH_TTL_SECONDS ?? 2592000);
    const accessToken = await this.jwt.signAsync(base, { secret: process.env.JWT_ACCESS_SECRET!, expiresIn: accessTtl });
    const refreshToken = await this.jwt.signAsync({ sub: user.id, sessionId }, { secret: process.env.JWT_REFRESH_SECRET!, expiresIn: refreshTtl });
    await this.prisma.refreshSession.create({ data: {
      id: sessionId, userId: user.id, tokenHash: await argon2.hash(refreshToken), deviceId, deviceName,
      ipAddress: this.ip(req), userAgent: req.headers['user-agent'], expiresAt: new Date(Date.now() + refreshTtl * 1000),
    } });
    return {
      accessToken, refreshToken, expiresIn: accessTtl,
      user: { id: user.id, username: user.username, email: user.email, phone: user.phone, roles: user.roles, locale: user.preferredLocale, profile: user.profile },
    };
  }

  private async enforceLimit(key: string, limit: number, seconds: number) {
    const result = await this.redis.rateLimit(key, limit, seconds);
    if (!result.allowed) throw new HttpException(`Too many requests. Try again in ${result.retryAfter} seconds.`, 429);
  }

  private ip(req: Request) { return req.ip || req.socket.remoteAddress || 'unknown'; }
  private maskEmail(email: string) {
    const [name, domain] = email.split('@');
    return `${(name ?? '').slice(0, 2)}***@${domain ?? ''}`;
  }

  private async sendRecoveryEmail(to: string, code: string) {
    const apiKey = process.env.RESEND_API_KEY;
    const from = process.env.EMAIL_FROM;
    if (!apiKey || !from) return false;
    try {
      const response = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        signal: AbortSignal.timeout(8000),
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${apiKey}` },
        body: JSON.stringify({
          from,
          to: [to],
          subject: 'MAURITANIA LUDO password reset',
          html: `<div style="font-family:Arial,sans-serif"><h2>MAURITANIA LUDO</h2><p>Your verification code is:</p><p style="font-size:30px;font-weight:700;letter-spacing:8px">${code}</p><p>This code expires in 10 minutes. If you did not request it, ignore this email.</p></div>`,
        }),
      });
      return response.ok;
    } catch { return false; }
  }
}
