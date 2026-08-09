import { Injectable, NotFoundException } from '@nestjs/common';
import type { Request } from 'express';
import { MatchStatus, NotificationType, Prisma, TransactionStatus, TransactionType, UserStatus } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { WalletsService } from '../wallets/wallets.service.js';
import { AdminAdjustDto } from '../wallets/dto/admin-adjust.dto.js';
import { UpdateStatusDto } from './dto/update-status.dto.js';
import { UpdateSettingDto } from './dto/update-setting.dto.js';
@Injectable()
export class AdminService {
  constructor(private readonly prisma: PrismaService, private readonly wallets: WalletsService) {}
  async dashboard() {
    const [users, activeUsers, activeMatches, waitingMatches, pendingTransactions, volume] = await Promise.all([
      this.prisma.user.count(), this.prisma.user.count({ where: { lastLoginAt: { gte: new Date(Date.now() - 24*3600*1000) } } }),
      this.prisma.match.count({ where: { status: MatchStatus.ACTIVE } }), this.prisma.match.count({ where: { status: { in: [MatchStatus.WAITING, MatchStatus.READY] } } }),
      this.prisma.financialTransaction.count({ where: { status: { in: ['PENDING','PROCESSING'] } } }),
      this.prisma.financialTransaction.aggregate({ _sum: { amount: true }, where: { status: 'COMPLETED' } }),
    ]);
    return { users, activeUsers24h: activeUsers, activeMatches, waitingMatches, pendingTransactions, completedVolume: volume._sum.amount ?? 0 };
  }
  async users(q?: string, cursor?: string) {
    const where: Prisma.UserWhereInput = q ? { OR: [{ username: { contains: q, mode: 'insensitive' } }, { email: { contains: q, mode: 'insensitive' } }, { phone: { contains: q } }, { profile: { displayName: { contains: q, mode: 'insensitive' } } }] } : {};
    const rows = await this.prisma.user.findMany({ where, include: { profile: true, walletAccounts: true }, orderBy: { createdAt: 'desc' }, take: 51, ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}) });
    return { items: rows.slice(0,50), nextCursor: rows.length > 50 ? rows[49].id : null };
  }
  async setStatus(actorUserId: string, userId: string, dto: UpdateStatusDto, req: Request) {
    const before = await this.prisma.user.findUnique({ where: { id: userId } }); if (!before) throw new NotFoundException();
    const after = await this.prisma.user.update({ where: { id: userId }, data: { status: dto.status } });
    await this.audit(actorUserId, 'USER_STATUS_CHANGED', 'User', userId, before, { ...after, reason: dto.reason }, req); return after;
  }
  async adjust(actorUserId: string, dto: AdminAdjustDto, req: Request) {
    const tx = await this.wallets.adjust({ userId: dto.userId, type: dto.accountType, amount: dto.amount, currency: dto.currency, reason: dto.reason, actorUserId, idempotencyKey: dto.idempotencyKey });
    await this.audit(actorUserId, 'WALLET_ADJUSTED', 'FinancialTransaction', tx.id, null, tx, req); return tx;
  }
  async transactions(cursor?: string, status?: string, type?: string) {
    const where: Prisma.FinancialTransactionWhereInput = {
      ...(status ? { status: status as TransactionStatus } : {}),
      ...(type ? { type: type as TransactionType } : {}),
    };
    const rows = await this.prisma.financialTransaction.findMany({ where, include: { user: { select: { username: true, profile: true } } }, orderBy: { createdAt: 'desc' }, take: 51, ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}) });
    return { items: rows.slice(0,50), nextCursor: rows.length > 50 ? rows[49].id : null };
  }
  async approveTransaction(actorUserId: string, id: string, req: Request) {
    const before = await this.prisma.financialTransaction.findUnique({ where: { id } });
    const after = await this.wallets.approveFinancialTransaction(id, actorUserId);
    await this.prisma.notification.create({ data: { userId: after.userId, type: NotificationType.WALLET, title: 'Transaction approved', body: `Your ${after.type.toLowerCase()} request was approved.`, data: { transactionId: after.id } } });
    await this.audit(actorUserId, 'TRANSACTION_APPROVED', 'FinancialTransaction', id, before, after, req);
    return after;
  }
  async rejectTransaction(actorUserId: string, id: string, reason: string, req: Request) {
    const before = await this.prisma.financialTransaction.findUnique({ where: { id } });
    const after = await this.wallets.rejectFinancialTransaction(id, actorUserId, reason);
    await this.prisma.notification.create({ data: { userId: after.userId, type: NotificationType.WALLET, title: 'Transaction rejected', body: reason, data: { transactionId: after.id } } });
    await this.audit(actorUserId, 'TRANSACTION_REJECTED', 'FinancialTransaction', id, before, after, req);
    return after;
  }
  async matches(status?: string, cursor?: string) { const rows = await this.prisma.match.findMany({ where: status ? { status: status as MatchStatus } : {}, include: { players: { include: { user: { select: { username: true } } } }, ruleSet: true }, orderBy: { createdAt: 'desc' }, take: 51, ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}) }); return { items: rows.slice(0,50), nextCursor: rows.length > 50 ? rows[49].id : null }; }
  match(id: string) { return this.prisma.match.findUnique({ where: { id }, include: { players: { include: { user: { include: { profile: true } } } }, events: { orderBy: { sequence: 'asc' } }, ruleSet: true } }); }
  settings() { return this.prisma.appSetting.findMany({ orderBy: { key: 'asc' } }); }
  async setting(actorUserId: string, key: string, dto: UpdateSettingDto, req: Request) { const before = await this.prisma.appSetting.findUnique({ where: { key } }); const after = await this.prisma.appSetting.upsert({ where: { key }, update: { value: dto.value as Prisma.InputJsonValue, description: dto.description, updatedBy: actorUserId }, create: { key, value: dto.value as Prisma.InputJsonValue, description: dto.description, updatedBy: actorUserId } }); await this.audit(actorUserId, 'SETTING_UPDATED', 'AppSetting', key, before, after, req); return after; }
  async audits(cursor?: string) { const rows = await this.prisma.auditLog.findMany({ include: { actor: { select: { username: true } } }, orderBy: { id: 'desc' }, take: 51, ...(cursor ? { cursor: { id: BigInt(cursor) }, skip: 1 } : {}) }); return { items: rows.slice(0,50).map((x) => ({ ...x, id: x.id.toString() })), nextCursor: rows.length > 50 ? rows[49].id.toString() : null }; }
  private audit(actorUserId: string, action: string, entityType: string, entityId: string, before: any, after: any, req: Request) {
    const json = (value: any) => value == null ? undefined : JSON.parse(JSON.stringify(value));
    return this.prisma.auditLog.create({ data: { actorUserId, action, entityType, entityId, before: json(before), after: json(after), ipAddress: req.ip, userAgent: req.headers['user-agent'] } });
  }
}
