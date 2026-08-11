import { BadRequestException, ForbiddenException, HttpException, Injectable, NotFoundException } from '@nestjs/common';
import { NotificationType, SupportTicketStatus } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { RedisService } from '../redis/redis.service.js';
import { CreateSupportTicketDto, SupportMessageDto, UpdateSupportStatusDto } from './dto/support.dto.js';

@Injectable()
export class SupportService {
  constructor(private readonly prisma: PrismaService, private readonly redis: RedisService) {}

  mine(userId: string) {
    return this.prisma.supportTicket.findMany({ where: { userId }, orderBy: { updatedAt: 'desc' }, take: 100 });
  }

  async create(userId: string, dto: CreateSupportTicketDto) {
    await this.enforceLimit(`support:create:${userId}`, 8, 3600);
    const ticket = await this.prisma.supportTicket.create({ data: {
      userId,
      subject: dto.subject.trim(),
      category: dto.category.trim().toUpperCase(),
      priority: dto.priority ?? 2,
    } });
    await this.prisma.supportMessage.create({ data: { ticketId: ticket.id, userId, text: dto.message.trim(), isStaff: false } });
    return this.getForUser(ticket.id, userId);
  }

  async getForUser(id: string, userId: string) {
    const ticket = await this.prisma.supportTicket.findUnique({ where: { id } });
    if (!ticket) throw new NotFoundException('Support ticket not found');
    if (ticket.userId !== userId) throw new ForbiddenException();
    const messages = await this.prisma.supportMessage.findMany({ where: { ticketId: id }, orderBy: { createdAt: 'asc' } });
    return { ...ticket, messages };
  }

  async userReply(id: string, userId: string, dto: SupportMessageDto) {
    await this.enforceLimit(`support:reply:${userId}`, 40, 600);
    const ticket = await this.prisma.supportTicket.findUnique({ where: { id } });
    if (!ticket) throw new NotFoundException('Support ticket not found');
    if (ticket.userId !== userId) throw new ForbiddenException();
    await this.prisma.$transaction([
      this.prisma.supportMessage.create({ data: { ticketId: id, userId, text: dto.text.trim(), isStaff: false } }),
      this.prisma.supportTicket.update({ where: { id }, data: { status: SupportTicketStatus.OPEN, lastMessageAt: new Date() } }),
    ]);
    return this.getForUser(id, userId);
  }

  async close(id: string, userId: string) {
    const ticket = await this.prisma.supportTicket.findUnique({ where: { id } });
    if (!ticket) throw new NotFoundException('Support ticket not found');
    if (ticket.userId !== userId) throw new ForbiddenException();
    return this.prisma.supportTicket.update({ where: { id }, data: { status: SupportTicketStatus.CLOSED } });
  }

  async adminList(status?: string) {
    if (status && !Object.values(SupportTicketStatus).includes(status as SupportTicketStatus)) throw new BadRequestException('Invalid support ticket status');
    const rows = await this.prisma.supportTicket.findMany({
      where: status ? { status: status as SupportTicketStatus } : {},
      orderBy: { lastMessageAt: 'desc' },
      take: 200,
    });
    const users = rows.length ? await this.prisma.user.findMany({ where: { id: { in: rows.map((x) => x.userId) } }, select: { id: true, username: true, email: true, phone: true, profile: true } }) : [];
    const map = new Map(users.map((u) => [u.id, u]));
    return rows.map((row) => ({ ...row, user: map.get(row.userId) ?? null }));
  }

  async adminGet(id: string) {
    const ticket = await this.prisma.supportTicket.findUnique({ where: { id } });
    if (!ticket) throw new NotFoundException('Support ticket not found');
    const [messages, user] = await Promise.all([
      this.prisma.supportMessage.findMany({ where: { ticketId: id }, orderBy: { createdAt: 'asc' } }),
      this.prisma.user.findUnique({ where: { id: ticket.userId }, select: { id: true, username: true, email: true, phone: true, profile: true } }),
    ]);
    return { ...ticket, messages, user };
  }

  async adminReply(id: string, staffUserId: string, dto: SupportMessageDto) {
    const ticket = await this.prisma.supportTicket.findUnique({ where: { id } });
    if (!ticket) throw new NotFoundException('Support ticket not found');
    await this.prisma.$transaction([
      this.prisma.supportMessage.create({ data: { ticketId: id, userId: staffUserId, text: dto.text.trim(), isStaff: true } }),
      this.prisma.supportTicket.update({ where: { id }, data: { status: SupportTicketStatus.WAITING_USER, lastMessageAt: new Date() } }),
      this.prisma.notification.create({ data: { userId: ticket.userId, type: NotificationType.SYSTEM, title: 'Support replied', body: dto.text.trim().slice(0, 160), data: { ticketId: id } } }),
    ]);
    return this.adminGet(id);
  }

  async setStatus(id: string, dto: UpdateSupportStatusDto) {
    const ticket = await this.prisma.supportTicket.findUnique({ where: { id } });
    if (!ticket) throw new NotFoundException('Support ticket not found');
    const updated = await this.prisma.supportTicket.update({ where: { id }, data: { status: dto.status as SupportTicketStatus } });
    await this.prisma.notification.create({ data: { userId: ticket.userId, type: NotificationType.SYSTEM, title: 'Support ticket updated', body: `Ticket status: ${dto.status}`, data: { ticketId: id, status: dto.status } } });
    return updated;
  }

  private async enforceLimit(key: string, limit: number, seconds: number) {
    const result = await this.redis.rateLimit(key, limit, seconds);
    if (!result.allowed) throw new HttpException(`Too many requests. Try again in ${result.retryAfter} seconds.`, 429);
  }
}
