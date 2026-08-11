import { Body, Controller, Delete, Get, Param, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../common/decorators/current-user.decorator.js';
import type { AuthUser } from '../common/decorators/current-user.decorator.js';
import { CreateRoomDto } from './dto/create-room.dto.js';
import { SendMessageDto } from './dto/send-message.dto.js';
import { SocialService } from './social.service.js';

@ApiBearerAuth()
@ApiTags('social')
@Controller('social')
export class SocialController {
  constructor(private readonly social: SocialService) {}
  @Get('rooms') rooms(@CurrentUser() user: AuthUser) { return this.social.rooms(user.sub); }
  @Post('rooms') create(@CurrentUser() user: AuthUser, @Body() dto: CreateRoomDto) { return this.social.create(user.sub, dto); }
  @Get('rooms/:id') room(@CurrentUser() user: AuthUser, @Param('id') id: string) { return this.social.get(id, user.sub); }
  @Post('rooms/:id/join') join(@CurrentUser() user: AuthUser, @Param('id') id: string) { return this.social.join(id, user.sub); }
  @Delete('rooms/:id/leave') leave(@CurrentUser() user: AuthUser, @Param('id') id: string) { return this.social.leave(id, user.sub); }
  @Get('rooms/:id/messages') messages(@CurrentUser() user: AuthUser, @Param('id') id: string) { return this.social.messages(id, user.sub); }
  @Post('rooms/:id/messages') send(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() dto: SendMessageDto) { return this.social.sendMessage(id, user.sub, dto); }
  @Post('rooms/:id/voice-session') voice(@CurrentUser() user: AuthUser, @Param('id') id: string) { return this.social.voiceSession(id, user.sub); }
}
