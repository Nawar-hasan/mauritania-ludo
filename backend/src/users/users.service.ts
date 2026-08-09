import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import { UpdateProfileDto } from './dto/update-profile.dto.js';
@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}
  async me(id: string) {
    const user = await this.prisma.user.findUnique({ where: { id }, select: {
      id: true, username: true, email: true, phone: true, status: true, roles: true, preferredLocale: true, createdAt: true,
      profile: true, walletAccounts: { orderBy: { type: 'asc' } },
      inventory: { where: { equipped: true }, include: { item: true } },
    } });
    if (!user) throw new NotFoundException('User not found');
    return user;
  }
  async update(id: string, dto: UpdateProfileDto) {
    const { locale, ...profile } = dto;
    return this.prisma.user.update({ where: { id }, data: {
      ...(locale ? { preferredLocale: locale } : {}),
      profile: { update: profile },
    }, include: { profile: true } });
  }
}
