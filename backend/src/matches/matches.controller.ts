import { Body, Controller, Delete, Get, Param, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../common/decorators/current-user.decorator.js';
import type { AuthUser } from '../common/decorators/current-user.decorator.js';
import { CreateMatchDto } from './dto/create-match.dto.js';
import { MoveDto } from './dto/move.dto.js';
import { MatchmakingDto } from './dto/matchmaking.dto.js';
import { MatchesService } from './matches.service.js';

@ApiBearerAuth()
@ApiTags('matches')
@Controller()
export class MatchesController {
  constructor(private readonly matches: MatchesService) {}

  @Get('matches/me')
  mine(@CurrentUser() user: AuthUser, @Query('cursor') cursor?: string) {
    return this.matches.listForUser(user.sub, cursor);
  }

  @Post('matches')
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateMatchDto) {
    return this.matches.create(user.sub, dto);
  }

  @Get('matches/code/:code')
  previewByCode(@CurrentUser() user: AuthUser, @Param('code') code: string) {
    return this.matches.previewByCode(code, user.sub);
  }

  @Post('matches/code/:code/join')
  joinByCode(@CurrentUser() user: AuthUser, @Param('code') code: string) {
    return this.matches.joinByCode(code, user.sub);
  }

  @Get('matches/:id')
  get(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.matches.getForUser(id, user.sub);
  }

  @Post('matches/:id/join')
  join(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.matches.join(id, user.sub);
  }

  @Post('matches/:id/start')
  start(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.matches.start(id, user.sub);
  }

  @Post('matches/:id/roll')
  roll(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.matches.roll(id, user.sub);
  }

  @Post('matches/:id/move')
  move(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() dto: MoveDto) {
    return this.matches.move(id, user.sub, dto);
  }

  @Post('matches/:id/forfeit')
  forfeit(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.matches.forfeit(id, user.sub);
  }

  @Post('matches/:id/cancel')
  cancelMatch(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.matches.cancelMatch(id, user.sub);
  }

  @Post('matches/:id/leave')
  leaveMatch(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.matches.leaveWaitingRoom(id, user.sub);
  }

  @Post('matchmaking/join')
  matchmaking(@CurrentUser() user: AuthUser, @Body() dto: MatchmakingDto) {
    return this.matches.matchmake(user.sub, dto);
  }

  @Get('matchmaking/:ticketId')
  ticket(@CurrentUser() user: AuthUser, @Param('ticketId') id: string) {
    return this.matches.getTicket(id, user.sub);
  }

  @Delete('matchmaking/:ticketId')
  cancel(@CurrentUser() user: AuthUser, @Param('ticketId') id: string) {
    return this.matches.cancelTicket(id, user.sub);
  }
}
