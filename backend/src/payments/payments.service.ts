import { BadRequestException, Injectable, NotFoundException, UnauthorizedException } from '@nestjs/common';
import { createHmac, timingSafeEqual } from 'node:crypto';
import {
  PaymentIntentStatus,
  PaymentMethodStatus,
  PaymentProvider,
  Prisma,
  TransactionStatus,
  TransactionType,
} from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { WalletsService } from '../wallets/wallets.service.js';
import { CreatePaymentIntentDto } from './dto/create-payment-intent.dto.js';

@Injectable()
export class PaymentsService {
  constructor(private readonly prisma: PrismaService, private readonly wallets: WalletsService) {}

  methods() {
    return this.prisma.paymentMethod.findMany({
      where: { status: PaymentMethodStatus.ACTIVE },
      select: {
        id: true, code: true, provider: true, nameAr: true, nameEn: true, supportsDeposit: true,
        supportsWithdrawal: true, currency: true, minAmount: true, maxAmount: true, feeFixed: true,
        feeRate: true, iconUrl: true, publicConfig: true, sortOrder: true,
      },
      orderBy: { sortOrder: 'asc' },
    });
  }

  intents(userId: string) {
    return this.prisma.paymentIntent.findMany({
      where: { userId }, include: { method: true }, orderBy: { createdAt: 'desc' }, take: 50,
    });
  }

  async createDepositIntent(userId: string, dto: CreatePaymentIntentDto) {
    await this.wallets.ensureDepositEligibility(userId);
    const method = await this.prisma.paymentMethod.findUnique({ where: { code: dto.methodCode } });
    if (!method || method.status !== PaymentMethodStatus.ACTIVE || !method.supportsDeposit) {
      throw new NotFoundException('Payment method is not available');
    }
    const receipt = await this.wallets.resolvePrivateReceipt(userId, dto.receiptFileId, dto.receiptUrl);
    if (method.provider === PaymentProvider.MANUAL && !receipt) throw new BadRequestException('A transfer receipt is required for manual deposits');
    const manualIdempotencyKey = receipt ? `manual-deposit:${userId}:${receipt.id}` : null;
    if (manualIdempotencyKey) {
      const existingTransaction = await this.prisma.financialTransaction.findUnique({ where: { idempotencyKey: manualIdempotencyKey } });
      if (existingTransaction) {
        const existingIntent = await this.prisma.paymentIntent.findFirst({ where: { transactionId: existingTransaction.id }, include: { method: true } });
        if (existingIntent) return { transaction: existingTransaction, intent: existingIntent, provider: method.provider };
      }
    }
    const amount = new Prisma.Decimal(dto.amount);
    if (amount.lessThan(method.minAmount) || amount.greaterThan(method.maxAmount)) {
      throw new BadRequestException(`Amount must be between ${method.minAmount} and ${method.maxAmount} ${method.currency}`);
    }
    const fee = method.feeFixed.add(amount.mul(method.feeRate));
    const created = await this.prisma.$transaction(async (tx) => {
      const transaction = await tx.financialTransaction.create({
        data: {
          userId, type: TransactionType.DEPOSIT, status: TransactionStatus.PENDING,
          amount, fee, currency: method.currency, externalRef: dto.externalRef, idempotencyKey: manualIdempotencyKey,
          description: `Deposit via ${method.code}`,
          metadata: { methodCode: method.code, phoneNumber: dto.phoneNumber ?? null, receiptFileId: receipt?.id ?? null, receiptUrl: receipt?.publicUrl ?? null },
        },
      });
      const intent = await tx.paymentIntent.create({
        data: {
          userId, methodId: method.id, transactionId: transaction.id, status: PaymentIntentStatus.PENDING,
          amount, fee, currency: method.currency, expiresAt: new Date(Date.now() + 30 * 60 * 1000),
          metadata: { phoneNumber: dto.phoneNumber ?? null, receiptFileId: receipt?.id ?? null, receiptUrl: receipt?.publicUrl ?? null },
        },
      });
      return { transaction, intent };
    });

    if (method.provider === PaymentProvider.MANUAL) {
      return { ...created, provider: 'MANUAL', instructions: method.publicConfig };
    }
    if (method.provider === PaymentProvider.MOOSYL) {
      const checkout = await this.createMoosylCheckout(created.intent.id, created.transaction.id, dto.amount, dto.phoneNumber);
      const intent = await this.prisma.paymentIntent.update({
        where: { id: created.intent.id },
        data: { checkoutUrl: checkout.checkoutUrl, providerRef: checkout.providerRef, metadata: { ...((created.intent.metadata as Record<string, unknown> | null) ?? {}), providerResponse: checkout.raw } as Prisma.InputJsonValue },
      });
      return { transaction: created.transaction, intent, provider: 'MOOSYL' };
    }
    throw new BadRequestException('Custom payment provider adapter is not configured');
  }

  private async createMoosylCheckout(intentId: string, transactionId: string, amount: number, phoneNumber?: string) {
    const endpoint = process.env.MOOSYL_CHECKOUT_ENDPOINT;
    const secret = process.env.MOOSYL_SECRET_KEY;
    if (!endpoint || !secret) throw new BadRequestException('Moosyl is not configured. Add test or live merchant credentials first.');
    const base = process.env.PUBLIC_APP_URL ?? 'https://example.invalid';
    const response = await fetch(endpoint, {
      method: 'POST',
      signal: AbortSignal.timeout(8000),
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${secret}` },
      body: JSON.stringify({
        transactionId,
        amount,
        phoneNumber,
        successUrl: `${base}/payments/success?intent=${intentId}`,
        cancelUrl: `${base}/payments/cancel?intent=${intentId}`,
        expiresInMinutes: 30,
      }),
    });
    const raw = await response.json().catch(() => ({})) as Record<string, any>;
    if (!response.ok || !raw.checkoutUrl) throw new BadRequestException(raw.message ?? 'Unable to create Moosyl checkout session');
    return { checkoutUrl: String(raw.checkoutUrl), providerRef: String(raw.id ?? raw.paymentRequestId ?? transactionId), raw };
  }

  async handleMoosylWebhook(rawBody: Buffer, signature: string | undefined, eventName: string | undefined) {
    const secret = process.env.MOOSYL_WEBHOOK_SECRET;
    if (!secret || !signature || !this.verifySignature(rawBody, signature, secret)) throw new UnauthorizedException('Invalid webhook signature');
    const payload = JSON.parse(rawBody.toString('utf8')) as { event?: string; data?: Record<string, any> };
    const event = eventName ?? payload.event;
    const data = payload.data ?? {};
    if (!['payment-created','payment-updated','payment-request-created','payment-request-updated'].includes(String(event))) {
      return { received: true, ignored: true };
    }
    const transactionId = String(data.transactionId ?? data.request?.transactionId ?? '');
    if (!transactionId) return { received: true, ignored: true };
    const intent = await this.prisma.paymentIntent.findFirst({ where: { transactionId } });
    if (!intent) return { received: true, ignored: true };
    const status = String(data.status ?? '').toLowerCase();
    if (['completed','succeeded','paid'].includes(status) && intent.status !== PaymentIntentStatus.SUCCEEDED) {
      await this.wallets.approveFinancialTransaction(transactionId, 'moosyl-webhook');
      await this.prisma.paymentIntent.update({
        where: { id: intent.id },
        data: { status: PaymentIntentStatus.SUCCEEDED, providerRef: String(data.id ?? data.referenceId ?? intent.providerRef ?? ''), completedAt: new Date(), metadata: data as Prisma.InputJsonValue },
      });
    } else if (['failed','cancelled','expired'].includes(status) && intent.status !== PaymentIntentStatus.SUCCEEDED) {
      const intentStatus = status === 'expired'
        ? PaymentIntentStatus.EXPIRED
        : status === 'cancelled'
          ? PaymentIntentStatus.CANCELLED
          : PaymentIntentStatus.FAILED;
      const transactionStatus = status === 'cancelled' || status === 'expired'
        ? TransactionStatus.CANCELLED
        : TransactionStatus.REJECTED;
      await this.prisma.$transaction([
        this.prisma.paymentIntent.update({
          where: { id: intent.id },
          data: { status: intentStatus, metadata: data as Prisma.InputJsonValue },
        }),
        this.prisma.financialTransaction.updateMany({
          where: { id: transactionId, type: TransactionType.DEPOSIT, status: { in: [TransactionStatus.PENDING, TransactionStatus.PROCESSING] } },
          data: { status: transactionStatus, processedAt: new Date() },
        }),
      ]);
    }
    return { received: true };
  }

  private verifySignature(raw: Buffer, signature: string, secret: string) {
    if (!signature.startsWith('sha256=')) return false;
    const expected = createHmac('sha256', secret).update(raw).digest('hex');
    const received = signature.slice(7);
    if (received.length !== expected.length || !/^[0-9a-f]{64}$/i.test(received)) return false;
    const receivedBytes = Buffer.from(received, 'hex');
    const expectedBytes = Buffer.from(expected, 'hex');
    return receivedBytes.length === expectedBytes.length && timingSafeEqual(receivedBytes, expectedBytes);
  }
}
