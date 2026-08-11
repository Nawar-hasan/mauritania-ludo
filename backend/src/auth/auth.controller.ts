import { Body, Controller, HttpCode, Post, Req } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import type { Request } from 'express';
import { Public } from '../common/decorators/public.decorator.js';
import { CurrentUser } from '../common/decorators/current-user.decorator.js';
import type { AuthUser } from '../common/decorators/current-user.decorator.js';
import { AuthService } from './auth.service.js';
import { RegisterDto } from './dto/register.dto.js';
import { LoginDto } from './dto/login.dto.js';
import { RefreshDto } from './dto/refresh.dto.js';
import { CompletePasswordResetDto, RequestPasswordResetDto, VerifyPasswordResetDto } from './dto/password-recovery.dto.js';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}
  @Public() @Post('register') register(@Body() dto: RegisterDto, @Req() req: Request) { return this.auth.register(dto, req); }
  @Public() @HttpCode(200) @Post('login') login(@Body() dto: LoginDto, @Req() req: Request) { return this.auth.login(dto, req); }
  @Public() @HttpCode(200) @Post('refresh') refresh(@Body() dto: RefreshDto, @Req() req: Request) { return this.auth.refresh(dto.refreshToken, req); }
  @Public() @HttpCode(200) @Post('password/forgot') forgot(@Body() dto: RequestPasswordResetDto, @Req() req: Request) { return this.auth.requestPasswordReset(dto, req); }
  @Public() @HttpCode(200) @Post('password/verify') verify(@Body() dto: VerifyPasswordResetDto, @Req() req: Request) { return this.auth.verifyPasswordReset(dto, req); }
  @Public() @HttpCode(200) @Post('password/reset') reset(@Body() dto: CompletePasswordResetDto, @Req() req: Request) { return this.auth.completePasswordReset(dto, req); }
  @HttpCode(204) @Post('logout') logout(@CurrentUser() user: AuthUser) { return this.auth.logout(user.sessionId); }
}
