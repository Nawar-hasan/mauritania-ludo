import { Body, Controller, Get, Param, Patch, Post, Query, Req } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import type { Request } from 'express';
import { Role } from '../generated/prisma/client.js';
import { CurrentUser } from '../common/decorators/current-user.decorator.js';
import type { AuthUser } from '../common/decorators/current-user.decorator.js';
import { Roles } from '../common/decorators/roles.decorator.js';
import { AdminService } from './admin.service.js';
import { UpdateStatusDto } from './dto/update-status.dto.js';
import { UpdateSettingDto } from './dto/update-setting.dto.js';
import { ProcessTransactionDto } from './dto/process-transaction.dto.js';
import { AdminAdjustDto } from '../wallets/dto/admin-adjust.dto.js';
@ApiBearerAuth() @ApiTags('admin') @Roles(Role.ADMIN, Role.SUPER_ADMIN)
@Controller('admin')
export class AdminController {
  constructor(private readonly admin: AdminService) {}
  @Get('dashboard') dashboard() { return this.admin.dashboard(); }
  @Get('users') users(@Query('q') q?: string, @Query('cursor') cursor?: string) { return this.admin.users(q, cursor); }
  @Patch('users/:id/status') status(@CurrentUser() actor: AuthUser, @Req() req: Request, @Param('id') id: string, @Body() dto: UpdateStatusDto) { return this.admin.setStatus(actor.sub, id, dto, req); }
  @Roles(Role.FINANCE, Role.ADMIN, Role.SUPER_ADMIN) @Post('wallets/adjust') adjust(@CurrentUser() actor: AuthUser, @Req() req: Request, @Body() dto: AdminAdjustDto) { return this.admin.adjust(actor.sub, dto, req); }
  @Get('transactions') transactions(@Query('cursor') cursor?: string, @Query('status') status?: string, @Query('type') type?: string) { return this.admin.transactions(cursor, status, type); }
  @Roles(Role.FINANCE, Role.ADMIN, Role.SUPER_ADMIN) @Post('transactions/:id/approve') approveTransaction(@CurrentUser() actor: AuthUser, @Req() req: Request, @Param('id') id: string) { return this.admin.approveTransaction(actor.sub, id, req); }
  @Roles(Role.FINANCE, Role.ADMIN, Role.SUPER_ADMIN) @Post('transactions/:id/reject') rejectTransaction(@CurrentUser() actor: AuthUser, @Req() req: Request, @Param('id') id: string, @Body() dto: ProcessTransactionDto) { return this.admin.rejectTransaction(actor.sub, id, dto.reason ?? 'Rejected by finance', req); }
  @Get('matches') matches(@Query('status') status?: string, @Query('cursor') cursor?: string) { return this.admin.matches(status, cursor); }
  @Get('matches/:id') match(@Param('id') id: string) { return this.admin.match(id); }
  @Get('settings') settings() { return this.admin.settings(); }
  @Patch('settings/:key') setting(@CurrentUser() actor: AuthUser, @Req() req: Request, @Param('key') key: string, @Body() dto: UpdateSettingDto) { return this.admin.setting(actor.sub, key, dto, req); }
  @Get('audit-logs') audits(@Query('cursor') cursor?: string) { return this.admin.audits(cursor); }
}
