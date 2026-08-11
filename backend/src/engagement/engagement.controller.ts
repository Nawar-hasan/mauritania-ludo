import { Body, Controller, Get, Param, Patch, Post, Put, Req } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import type { Request } from 'express';
import { Role } from '../generated/prisma/client.js';
import { CurrentUser } from '../common/decorators/current-user.decorator.js';
import type { AuthUser } from '../common/decorators/current-user.decorator.js';
import { Roles } from '../common/decorators/roles.decorator.js';
import { ApplyReferralDto, ReviewIdentityDto, SubmitIdentityDto, UpdatePrivacyDto, UpsertAchievementDto } from './dto/engagement.dto.js';
import { EngagementService } from './engagement.service.js';

@ApiBearerAuth() @ApiTags('engagement')
@Controller()
export class EngagementController {
  constructor(private readonly engagement: EngagementService) {}
  @Get('engagement/leaderboard') leaderboard() { return this.engagement.leaderboard(); }
  @Get('engagement/achievements') achievements(@CurrentUser() user: AuthUser) { return this.engagement.achievements(user.sub); }
  @Post('engagement/achievements/:id/claim') claim(@CurrentUser() user: AuthUser, @Param('id') id: string) { return this.engagement.claimAchievement(user.sub, id); }
  @Get('engagement/referral') referral(@CurrentUser() user: AuthUser) { return this.engagement.referralOverview(user.sub); }
  @Post('engagement/referral/apply') applyReferral(@CurrentUser() user: AuthUser, @Body() dto: ApplyReferralDto) { return this.engagement.applyReferral(user.sub, dto); }
  @Get('users/me/privacy') privacy(@CurrentUser() user: AuthUser) { return this.engagement.privacy(user.sub); }
  @Patch('users/me/privacy') updatePrivacy(@CurrentUser() user: AuthUser, @Body() dto: UpdatePrivacyDto) { return this.engagement.updatePrivacy(user.sub, dto); }
  @Get('users/me/identity') identity(@CurrentUser() user: AuthUser) { return this.engagement.identity(user.sub); }
  @Post('users/me/identity') submitIdentity(@CurrentUser() user: AuthUser, @Body() dto: SubmitIdentityDto) { return this.engagement.submitIdentity(user.sub, dto); }
}

@ApiBearerAuth() @ApiTags('admin-engagement') @Roles(Role.ADMIN, Role.SUPER_ADMIN)
@Controller('admin')
export class EngagementAdminController {
  constructor(private readonly engagement: EngagementService) {}
  @Get('identity/pending') identityQueue() { return this.engagement.identityQueue(); }
  @Patch('users/:id/identity') review(@CurrentUser() reviewer: AuthUser, @Param('id') id: string, @Body() dto: ReviewIdentityDto, @Req() req: Request) { return this.engagement.reviewIdentity(id, reviewer.sub, dto, { ipAddress: req.ip, userAgent: req.headers['user-agent'] }); }
  @Get('achievements') achievements() { return this.engagement.achievementDefinitions(); }
  @Post('achievements') createAchievement(@Body() dto: UpsertAchievementDto) { return this.engagement.upsertAchievement(null, dto); }
  @Put('achievements/:id') updateAchievement(@Param('id') id: string, @Body() dto: UpsertAchievementDto) { return this.engagement.upsertAchievement(id, dto); }
}
