import { Injectable } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { MatchStatus } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { MatchesService } from './matches.service.js';
@Injectable()
export class MatchTimeoutService {
  constructor(private readonly prisma: PrismaService, private readonly matches: MatchesService) {}
  @Cron('*/5 * * * * *') async tick() {
    const expired = await this.prisma.match.findMany({ where: { status: MatchStatus.ACTIVE, nextActionAt: { lte: new Date() } }, select: { id: true }, take: 50 });
    for (const match of expired) this.matches.processTimeout(match.id).catch((e) => console.error(`Timeout ${match.id}:`, e.message));
  }
}
