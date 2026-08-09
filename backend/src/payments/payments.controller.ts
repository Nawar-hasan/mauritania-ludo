import { Body, Controller, Get, Headers, Post, Req } from '@nestjs/common';
import type { RawBodyRequest } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import type { Request } from 'express';
import { CurrentUser } from '../common/decorators/current-user.decorator.js';
import type { AuthUser } from '../common/decorators/current-user.decorator.js';
import { Public } from '../common/decorators/public.decorator.js';
import { CreatePaymentIntentDto } from './dto/create-payment-intent.dto.js';
import { PaymentsService } from './payments.service.js';

@ApiTags('payments')
@Controller('payments')
export class PaymentsController {
  constructor(private readonly payments: PaymentsService) {}

  @Public() @Get('methods') methods() { return this.payments.methods(); }
  @ApiBearerAuth() @Get('intents/me') intents(@CurrentUser() user: AuthUser) { return this.payments.intents(user.sub); }
  @ApiBearerAuth() @Post('deposits') deposit(@CurrentUser() user: AuthUser, @Body() dto: CreatePaymentIntentDto) {
    return this.payments.createDepositIntent(user.sub, dto);
  }

  @Public()
  @Post('webhooks/moosyl')
  webhook(
    @Req() req: RawBodyRequest<Request>,
    @Headers('x-webhook-signature') signature?: string,
    @Headers('x-webhook-event') event?: string,
  ) {
    return this.payments.handleMoosylWebhook(req.rawBody ?? Buffer.from(JSON.stringify(req.body ?? {})), signature, event);
  }
}
