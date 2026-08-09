import { Body, Controller, Get, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../common/decorators/current-user.decorator.js';
import type { AuthUser } from '../common/decorators/current-user.decorator.js';
import { WalletsService } from './wallets.service.js';
import { CreateDepositDto } from './dto/create-deposit.dto.js';
import { CreateWithdrawalDto } from './dto/create-withdrawal.dto.js';

@ApiBearerAuth()
@ApiTags('wallets')
@Controller('wallets/me')
export class WalletsController {
  constructor(private readonly wallets: WalletsService) {}

  @Get()
  get(@CurrentUser() user: AuthUser) {
    return this.wallets.getSummary(user.sub);
  }

  @Get('ledger')
  ledger(@CurrentUser() user: AuthUser, @Query('cursor') cursor?: string) {
    return this.wallets.getLedger(user.sub, cursor);
  }

  @Get('transactions')
  transactions(@CurrentUser() user: AuthUser, @Query('cursor') cursor?: string) {
    return this.wallets.getTransactions(user.sub, cursor);
  }

  @Post('deposits')
  deposit(@CurrentUser() user: AuthUser, @Body() dto: CreateDepositDto) {
    return this.wallets.createDepositRequest(user.sub, dto);
  }

  @Post('withdrawals')
  withdrawal(@CurrentUser() user: AuthUser, @Body() dto: CreateWithdrawalDto) {
    return this.wallets.createWithdrawalRequest(user.sub, dto);
  }
}
