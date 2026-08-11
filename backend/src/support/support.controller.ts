import { Body, Controller, Get, Param, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Role } from '../generated/prisma/client.js';
import { CurrentUser } from '../common/decorators/current-user.decorator.js';
import type { AuthUser } from '../common/decorators/current-user.decorator.js';
import { Roles } from '../common/decorators/roles.decorator.js';
import { CreateSupportTicketDto, SupportMessageDto, UpdateSupportStatusDto } from './dto/support.dto.js';
import { SupportService } from './support.service.js';

@ApiBearerAuth() @ApiTags('support') @Controller('support')
export class SupportController {
  constructor(private readonly support: SupportService) {}
  @Get('tickets') async mine(@CurrentUser() user: AuthUser) { return { items: await this.support.mine(user.sub) }; }
  @Post('tickets') create(@CurrentUser() user: AuthUser, @Body() dto: CreateSupportTicketDto) { return this.support.create(user.sub, dto); }
  @Get('tickets/:id') get(@CurrentUser() user: AuthUser, @Param('id') id: string) { return this.support.getForUser(id, user.sub); }
  @Post('tickets/:id/messages') reply(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() dto: SupportMessageDto) { return this.support.userReply(id, user.sub, dto); }
  @Post('tickets/:id/close') close(@CurrentUser() user: AuthUser, @Param('id') id: string) { return this.support.close(id, user.sub); }
}

@ApiBearerAuth() @ApiTags('admin-support') @Roles(Role.SUPPORT, Role.ADMIN, Role.SUPER_ADMIN) @Controller('admin/support')
export class SupportAdminController {
  constructor(private readonly support: SupportService) {}
  @Get('tickets') list(@Query('status') status?: string) { return this.support.adminList(status); }
  @Get('tickets/:id') get(@Param('id') id: string) { return this.support.adminGet(id); }
  @Post('tickets/:id/messages') reply(@CurrentUser() staff: AuthUser, @Param('id') id: string, @Body() dto: SupportMessageDto) { return this.support.adminReply(id, staff.sub, dto); }
  @Patch('tickets/:id/status') status(@Param('id') id: string, @Body() dto: UpdateSupportStatusDto) { return this.support.setStatus(id, dto); }
}
