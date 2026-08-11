import { Body, Controller, Delete, Get, Param, Patch, Post, Put } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Role } from '../generated/prisma/client.js';
import { CurrentUser } from '../common/decorators/current-user.decorator.js';
import type { AuthUser } from '../common/decorators/current-user.decorator.js';
import { Roles } from '../common/decorators/roles.decorator.js';
import { CreateTournamentDto } from './dto/tournament.dto.js';
import { TournamentsService } from './tournaments.service.js';

@ApiBearerAuth() @ApiTags('tournaments') @Controller('tournaments')
export class TournamentsController {
  constructor(private readonly tournaments: TournamentsService) {}
  @Get() list(@CurrentUser() user: AuthUser) { return this.tournaments.list(user.sub); }
  @Get(':id') details(@CurrentUser() user: AuthUser, @Param('id') id: string) { return this.tournaments.details(id, user.sub); }
  @Post(':id/join') join(@CurrentUser() user: AuthUser, @Param('id') id: string) { return this.tournaments.join(id, user.sub); }
  @Delete(':id/join') withdraw(@CurrentUser() user: AuthUser, @Param('id') id: string) { return this.tournaments.withdraw(id, user.sub); }
}

@ApiBearerAuth() @ApiTags('admin-tournaments') @Roles(Role.ADMIN, Role.SUPER_ADMIN) @Controller('admin/tournaments')
export class TournamentsAdminController {
  constructor(private readonly tournaments: TournamentsService) {}
  @Get() list() { return this.tournaments.adminList(); }
  @Post() create(@Body() dto: CreateTournamentDto) { return this.tournaments.create(dto); }
  @Put(':id') update(@Param('id') id: string, @Body() dto: CreateTournamentDto) { return this.tournaments.update(id, dto); }
  @Post(':id/open') open(@Param('id') id: string) { return this.tournaments.open(id); }
  @Post(':id/start') start(@Param('id') id: string) { return this.tournaments.start(id); }
  @Post(':id/cancel') cancel(@Param('id') id: string) { return this.tournaments.cancel(id); }
}
