import { ConflictException, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import type { Request } from 'express';
import argon2 from 'argon2';
import { randomUUID } from 'node:crypto';
import { PrismaService } from '../prisma/prisma.service.js';
import { Role, UserStatus, WalletType } from '../generated/prisma/client.js';
import { RegisterDto } from './dto/register.dto.js';
import { LoginDto } from './dto/login.dto.js';

@Injectable()
export class AuthService {
  constructor(private readonly prisma: PrismaService, private readonly jwt: JwtService) {}

  async register(dto: RegisterDto, req: Request) {
    if (!dto.email && !dto.phone) throw new ConflictException('Email or phone is required');
    const exists = await this.prisma.user.findFirst({ where: { OR: [{ username: dto.username }, ...(dto.email ? [{ email: dto.email }] : []), ...(dto.phone ? [{ phone: dto.phone }] : [])] } });
    if (exists) throw new ConflictException('Username, email or phone already exists');
    const passwordHash = await argon2.hash(dto.password);
    const user = await this.prisma.$transaction(async (tx) => {
      const created = await tx.user.create({ data: {
        username: dto.username, email: dto.email, phone: dto.phone, passwordHash,
        preferredLocale: dto.locale ?? 'ar', roles: [Role.PLAYER],
        profile: { create: { displayName: dto.displayName } },
      }, include: { profile: true } });
      await tx.walletAccount.createMany({ data: Object.values(WalletType).map((type) => ({ userId: created.id, type, currency: 'MRU' })) });
      return created;
    });
    return this.issueTokens(user, req, undefined, undefined);
  }

  async login(dto: LoginDto, req: Request) {
    const user = await this.prisma.user.findFirst({ where: { OR: [{ username: dto.identifier }, { email: dto.identifier }, { phone: dto.identifier }] }, include: { profile: true } });
    if (!user || !(await argon2.verify(user.passwordHash, dto.password))) throw new UnauthorizedException('Invalid credentials');
    if (user.status !== UserStatus.ACTIVE) throw new UnauthorizedException(`Account is ${user.status.toLowerCase()}`);
    await this.prisma.user.update({ where: { id: user.id }, data: { lastLoginAt: new Date() } });
    return this.issueTokens(user, req, dto.deviceId, dto.deviceName);
  }

  async refresh(rawToken: string, req: Request) {
    let payload: { sub: string; sessionId: string };
    try { payload = await this.jwt.verifyAsync(rawToken, { secret: process.env.JWT_REFRESH_SECRET! }); }
    catch { throw new UnauthorizedException('Invalid refresh token'); }
    const session = await this.prisma.refreshSession.findUnique({ where: { id: payload.sessionId }, include: { user: { include: { profile: true } } } });
    if (!session || session.revokedAt || session.expiresAt <= new Date() || !(await argon2.verify(session.tokenHash, rawToken))) throw new UnauthorizedException('Refresh session is invalid');
    await this.prisma.refreshSession.update({ where: { id: session.id }, data: { revokedAt: new Date(), lastUsedAt: new Date() } });
    return this.issueTokens(session.user, req, session.deviceId ?? undefined, session.deviceName ?? undefined);
  }

  async logout(sessionId: string) {
    await this.prisma.refreshSession.updateMany({ where: { id: sessionId, revokedAt: null }, data: { revokedAt: new Date() } });
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
      ipAddress: req.ip, userAgent: req.headers['user-agent'], expiresAt: new Date(Date.now() + refreshTtl * 1000),
    } });
    return {
      accessToken, refreshToken, expiresIn: accessTtl,
      user: { id: user.id, username: user.username, email: user.email, phone: user.phone, roles: user.roles, locale: user.preferredLocale, profile: user.profile },
    };
  }
}
