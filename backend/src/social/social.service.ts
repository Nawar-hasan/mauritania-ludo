import { BadRequestException, ForbiddenException, Injectable, NotFoundException, ServiceUnavailableException } from '@nestjs/common';
import { SocialRoomMemberRole, SocialRoomType, SocialRoomVisibility } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { CreateRoomDto } from './dto/create-room.dto.js';
import { SendMessageDto } from './dto/send-message.dto.js';

@Injectable()
export class SocialService {
  constructor(private readonly prisma: PrismaService) {}

  async rooms(userId: string) {
    return this.prisma.socialRoom.findMany({
      where: { active: true, OR: [{ visibility: SocialRoomVisibility.PUBLIC }, { members: { some: { userId } } }] },
      include: {
        owner: { select: { username: true, profile: true } },
        members: { include: { user: { select: { username: true, profile: true } } }, orderBy: { joinedAt: 'asc' }, take: 50 },
        _count: { select: { members: true, messages: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  async create(userId: string, dto: CreateRoomDto) {
    const name = dto.name.trim();
    if (!name) throw new BadRequestException('Room name is required');
    return this.prisma.socialRoom.create({
      data: {
        name,
        description: dto.description?.trim() || null,
        type: dto.type,
        visibility: dto.visibility ?? SocialRoomVisibility.PUBLIC,
        ownerUserId: userId,
        maxParticipants: dto.maxParticipants ?? (dto.type === SocialRoomType.VOICE ? 12 : 30),
        members: { create: { userId, role: SocialRoomMemberRole.HOST } },
      },
      include: { owner: { select: { username: true, profile: true } }, members: { include: { user: { select: { username: true, profile: true } } } }, _count: { select: { members: true, messages: true } } },
    });
  }

  async get(id: string, userId: string) {
    const room = await this.prisma.socialRoom.findUnique({
      where: { id },
      include: { owner: { select: { username: true, profile: true } }, members: { include: { user: { select: { username: true, profile: true } } }, orderBy: { joinedAt: 'asc' } }, _count: { select: { members: true, messages: true } } },
    });
    if (!room || !room.active) throw new NotFoundException('Room not found');
    if (room.visibility === SocialRoomVisibility.PRIVATE && !room.members.some((m) => m.userId === userId)) throw new ForbiddenException();
    return room;
  }

  async join(id: string, userId: string) {
    const room = await this.prisma.socialRoom.findUnique({
      where: { id },
      include: { members: { select: { userId: true } }, _count: { select: { members: true } } },
    });
    if (!room || !room.active) throw new NotFoundException('Room not found');

    const alreadyMember = room.members.some((member) => member.userId === userId);
    if (room.visibility === SocialRoomVisibility.PRIVATE && !alreadyMember) {
      throw new ForbiddenException('This private room requires an invitation');
    }
    if (!alreadyMember && room._count.members >= room.maxParticipants) {
      throw new BadRequestException('Room is full');
    }

    if (!alreadyMember) {
      await this.prisma.socialRoomMember.create({
        data: { roomId: id, userId, role: SocialRoomMemberRole.MEMBER },
      });
    }
    return this.get(id, userId);
  }

  async leave(id: string, userId: string) {
    const room = await this.prisma.socialRoom.findUnique({ where: { id } });
    if (!room) throw new NotFoundException('Room not found');
    if (room.ownerUserId === userId) {
      await this.prisma.socialRoom.update({ where: { id }, data: { active: false } });
      return { left: true, closed: true };
    }
    await this.prisma.socialRoomMember.deleteMany({ where: { roomId: id, userId } });
    return { left: true, closed: false };
  }

  async messages(id: string, userId: string) {
    await this.ensureMember(id, userId);
    return this.prisma.socialMessage.findMany({
      where: { roomId: id },
      include: { user: { select: { username: true, profile: true } } },
      orderBy: { createdAt: 'asc' },
      take: 200,
    });
  }

  async sendMessage(id: string, userId: string, dto: SendMessageDto) {
    await this.ensureMember(id, userId);
    const text = dto.text.trim();
    if (!text) throw new BadRequestException('Message is empty');
    const message = await this.prisma.socialMessage.create({
      data: { roomId: id, userId, text },
      include: { user: { select: { username: true, profile: true } } },
    });
    return message;
  }

  async voiceSession(id: string, userId: string) {
    const room = await this.ensureMember(id, userId);
    if (room.type !== SocialRoomType.VOICE) throw new BadRequestException('This is not a voice room');
    const endpoint = process.env.VOICE_TOKEN_ENDPOINT;
    const apiKey = process.env.VOICE_API_KEY;
    const provider = process.env.VOICE_PROVIDER ?? 'CUSTOM';
    if (!endpoint || !apiKey) {
      throw new ServiceUnavailableException('Voice provider is not configured. Set VOICE_TOKEN_ENDPOINT and VOICE_API_KEY.');
    }
    const user = await this.prisma.user.findUnique({ where: { id: userId }, include: { profile: true } });
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${apiKey}` },
      body: JSON.stringify({ roomId: room.voiceProviderRoom ?? room.id, userId, displayName: user?.profile?.displayName ?? user?.username ?? userId, provider }),
    });
    const payload = await response.json().catch(() => ({})) as Record<string, unknown>;
    if (!response.ok) throw new ServiceUnavailableException(String(payload['message'] ?? 'Voice provider rejected the session request'));
    return { provider, roomId: room.id, ...payload };
  }

  private async ensureMember(id: string, userId: string) {
    const room = await this.prisma.socialRoom.findUnique({ where: { id } });
    if (!room || !room.active) throw new NotFoundException('Room not found');
    const member = await this.prisma.socialRoomMember.findUnique({ where: { roomId_userId: { roomId: id, userId } } });
    if (!member) throw new ForbiddenException('Join the room first');
    return room;
  }
}
