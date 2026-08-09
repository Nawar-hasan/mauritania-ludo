import { Body, Controller, Get, Patch } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../common/decorators/current-user.decorator.js';
import type { AuthUser } from '../common/decorators/current-user.decorator.js';
import { UsersService } from './users.service.js';
import { UpdateProfileDto } from './dto/update-profile.dto.js';
@ApiBearerAuth() @ApiTags('users') @Controller('users')
export class UsersController {
  constructor(private readonly users: UsersService) {}
  @Get('me') me(@CurrentUser() user: AuthUser) { return this.users.me(user.sub); }
  @Patch('me') update(@CurrentUser() user: AuthUser, @Body() dto: UpdateProfileDto) { return this.users.update(user.sub, dto); }
}
