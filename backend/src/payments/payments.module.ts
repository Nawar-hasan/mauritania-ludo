import { Module } from '@nestjs/common';
import { WalletsModule } from '../wallets/wallets.module.js';
import { PaymentsController } from './payments.controller.js';
import { PaymentsService } from './payments.service.js';

@Module({ imports: [WalletsModule], controllers: [PaymentsController], providers: [PaymentsService], exports: [PaymentsService] })
export class PaymentsModule {}
