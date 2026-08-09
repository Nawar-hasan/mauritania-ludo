import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import {
  Prisma,
  LedgerDirection,
  TransactionStatus,
  TransactionType,
  WalletType,
  PaymentMethodStatus,
  PaymentIntentStatus,
} from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { CreateDepositDto } from './dto/create-deposit.dto.js';
import { CreateWithdrawalDto } from './dto/create-withdrawal.dto.js';

@Injectable()
export class WalletsService {
  constructor(private readonly prisma: PrismaService) {}

  getAccounts(userId: string) {
    return this.prisma.walletAccount.findMany({ where: { userId }, orderBy: { type: 'asc' } });
  }

  async getSummary(userId: string) {
    const accounts = await this.getAccounts(userId);
    const byType = Object.fromEntries(accounts.map((account) => [account.type, Number(account.balance)]));
    return {
      currency: accounts[0]?.currency ?? 'MRU',
      accounts,
      balances: {
        cash: byType.CASH ?? 0,
        bonus: byType.BONUS ?? 0,
        coins: byType.COINS ?? 0,
        gems: byType.GEMS ?? 0,
        locked: byType.LOCKED ?? 0,
      },
    };
  }

  async getLedger(userId: string, cursor?: string) {
    const rows = await this.prisma.ledgerEntry.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 51,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
    });
    return { items: rows.slice(0, 50), nextCursor: rows.length > 50 ? rows[49].id : null };
  }

  async getTransactions(userId: string, cursor?: string) {
    const rows = await this.prisma.financialTransaction.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 51,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
    });
    return { items: rows.slice(0, 50), nextCursor: rows.length > 50 ? rows[49].id : null };
  }

  async createDepositRequest(userId: string, dto: CreateDepositDto) {
    const method = await this.prisma.paymentMethod.findUnique({ where: { code: dto.method } });
    if (!method || method.status !== PaymentMethodStatus.ACTIVE || !method.supportsDeposit) {
      throw new BadRequestException('Payment method is not available for deposits');
    }
    const amount = new Prisma.Decimal(dto.amount);
    if (amount.lessThan(method.minAmount) || amount.greaterThan(method.maxAmount)) {
      throw new BadRequestException(`Deposit must be between ${method.minAmount} and ${method.maxAmount} ${method.currency}`);
    }
    const fee = method.feeFixed.add(amount.mul(method.feeRate));
    return this.prisma.financialTransaction.create({
      data: {
        userId,
        type: TransactionType.DEPOSIT,
        status: TransactionStatus.PENDING,
        amount,
        fee,
        currency: method.currency,
        externalRef: dto.externalRef,
        description: `Deposit request via ${method.code}`,
        metadata: {
          method: method.code,
          provider: method.provider,
          receiptUrl: dto.receiptUrl ?? null,
        },
      },
    });
  }

  async createWithdrawalRequest(userId: string, dto: CreateWithdrawalDto) {
    const method = await this.prisma.paymentMethod.findUnique({ where: { code: dto.method } });
    if (!method || method.status !== PaymentMethodStatus.ACTIVE || !method.supportsWithdrawal) {
      throw new BadRequestException('Payment method is not available for withdrawals');
    }
    const [globalMinimum, globalMaximum] = await Promise.all([
      this.settingNumber('minimum_withdrawal', 300),
      this.settingNumber('maximum_withdrawal', 100000),
    ]);
    const minimum = Math.max(globalMinimum, Number(method.minAmount));
    const maximum = Math.min(globalMaximum, Number(method.maxAmount));
    if (!Number.isFinite(dto.amount) || dto.amount < minimum || dto.amount > maximum) {
      throw new BadRequestException(`Withdrawal must be between ${minimum} and ${maximum} ${method.currency}`);
    }
    const amount = new Prisma.Decimal(dto.amount);
    const fee = method.feeFixed.add(amount.mul(method.feeRate));
    const netAmount = amount.sub(fee);
    if (netAmount.lessThanOrEqualTo(0)) throw new BadRequestException('Withdrawal amount must be greater than its fees');
    return this.prisma.$transaction(async (tx) => {
      const cash = await tx.walletAccount.findUnique({
        where: { userId_type_currency: { userId, type: WalletType.CASH, currency: method.currency } },
      });
      const locked = await tx.walletAccount.findUnique({
        where: { userId_type_currency: { userId, type: WalletType.LOCKED, currency: method.currency } },
      });
      if (!cash || !locked) throw new NotFoundException('Wallet account not found');
      if (cash.balance.lessThan(amount)) throw new BadRequestException('Insufficient balance');

      const transaction = await tx.financialTransaction.create({
        data: {
          userId,
          type: TransactionType.WITHDRAWAL,
          status: TransactionStatus.PENDING,
          amount,
          fee,
          currency: method.currency,
          description: `Withdrawal request via ${method.code}`,
          metadata: {
            method: method.code,
            provider: method.provider,
            accountNumber: dto.accountNumber,
            accountName: dto.accountName,
            note: dto.note,
            netAmount: netAmount.toString(),
          },
        },
      });

      const cashAfter = cash.balance.sub(amount);
      const lockedAfter = locked.balance.add(amount);
      await tx.walletAccount.update({ where: { id: cash.id }, data: { balance: cashAfter, version: { increment: 1 } } });
      await tx.walletAccount.update({ where: { id: locked.id }, data: { balance: lockedAfter, version: { increment: 1 } } });
      await tx.ledgerEntry.createMany({
        data: [
          {
            userId,
            accountId: cash.id,
            transactionId: transaction.id,
            direction: LedgerDirection.DEBIT,
            amount,
            balanceBefore: cash.balance,
            balanceAfter: cashAfter,
            referenceType: 'WITHDRAWAL',
            referenceId: transaction.id,
            description: 'Withdrawal funds reserved',
          },
          {
            userId,
            accountId: locked.id,
            transactionId: transaction.id,
            direction: LedgerDirection.CREDIT,
            amount,
            balanceBefore: locked.balance,
            balanceAfter: lockedAfter,
            referenceType: 'WITHDRAWAL',
            referenceId: transaction.id,
            description: 'Withdrawal funds reserved',
          },
        ],
      });
      return transaction;
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
  }

  async approveFinancialTransaction(transactionId: string, actorUserId: string) {
    return this.prisma.$transaction(async (tx) => {
      const transaction = await tx.financialTransaction.findUnique({ where: { id: transactionId } });
      if (!transaction) throw new NotFoundException('Transaction not found');
      if (transaction.status !== TransactionStatus.PENDING && transaction.status !== TransactionStatus.PROCESSING) {
        throw new BadRequestException('Transaction is not pending');
      }

      if (transaction.type === TransactionType.DEPOSIT) {
        const cash = await tx.walletAccount.findUnique({
          where: { userId_type_currency: { userId: transaction.userId, type: WalletType.CASH, currency: transaction.currency } },
        });
        if (!cash) throw new NotFoundException('Cash wallet not found');
        const after = cash.balance.add(transaction.amount);
        await tx.walletAccount.update({ where: { id: cash.id }, data: { balance: after, version: { increment: 1 } } });
        await tx.ledgerEntry.create({
          data: {
            userId: transaction.userId,
            accountId: cash.id,
            transactionId: transaction.id,
            direction: LedgerDirection.CREDIT,
            amount: transaction.amount,
            balanceBefore: cash.balance,
            balanceAfter: after,
            referenceType: 'DEPOSIT',
            referenceId: transaction.id,
            description: 'Deposit approved',
          },
        });
      } else if (transaction.type === TransactionType.WITHDRAWAL) {
        const locked = await tx.walletAccount.findUnique({
          where: { userId_type_currency: { userId: transaction.userId, type: WalletType.LOCKED, currency: transaction.currency } },
        });
        if (!locked || locked.balance.lessThan(transaction.amount)) throw new BadRequestException('Reserved withdrawal balance is unavailable');
        const after = locked.balance.sub(transaction.amount);
        await tx.walletAccount.update({ where: { id: locked.id }, data: { balance: after, version: { increment: 1 } } });
        await tx.ledgerEntry.create({
          data: {
            userId: transaction.userId,
            accountId: locked.id,
            transactionId: transaction.id,
            direction: LedgerDirection.DEBIT,
            amount: transaction.amount,
            balanceBefore: locked.balance,
            balanceAfter: after,
            referenceType: 'WITHDRAWAL',
            referenceId: transaction.id,
            description: 'Withdrawal completed',
          },
        });
      } else {
        throw new BadRequestException('Only deposit and withdrawal requests can be approved here');
      }

      const updated = await tx.financialTransaction.update({
        where: { id: transaction.id },
        data: {
          status: TransactionStatus.COMPLETED,
          processedAt: new Date(),
          metadata: {
            ...((transaction.metadata as Record<string, unknown> | null) ?? {}),
            processedBy: actorUserId,
          },
        },
      });
      await tx.paymentIntent.updateMany({
        where: { transactionId: transaction.id },
        data: { status: PaymentIntentStatus.SUCCEEDED, completedAt: new Date() },
      });
      return updated;
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
  }

  async rejectFinancialTransaction(transactionId: string, actorUserId: string, reason: string) {
    return this.prisma.$transaction(async (tx) => {
      const transaction = await tx.financialTransaction.findUnique({ where: { id: transactionId } });
      if (!transaction) throw new NotFoundException('Transaction not found');
      if (transaction.status !== TransactionStatus.PENDING && transaction.status !== TransactionStatus.PROCESSING) {
        throw new BadRequestException('Transaction is not pending');
      }

      if (transaction.type === TransactionType.WITHDRAWAL) {
        const cash = await tx.walletAccount.findUnique({
          where: { userId_type_currency: { userId: transaction.userId, type: WalletType.CASH, currency: transaction.currency } },
        });
        const locked = await tx.walletAccount.findUnique({
          where: { userId_type_currency: { userId: transaction.userId, type: WalletType.LOCKED, currency: transaction.currency } },
        });
        if (!cash || !locked || locked.balance.lessThan(transaction.amount)) throw new BadRequestException('Reserved withdrawal balance is unavailable');
        const cashAfter = cash.balance.add(transaction.amount);
        const lockedAfter = locked.balance.sub(transaction.amount);
        await tx.walletAccount.update({ where: { id: cash.id }, data: { balance: cashAfter, version: { increment: 1 } } });
        await tx.walletAccount.update({ where: { id: locked.id }, data: { balance: lockedAfter, version: { increment: 1 } } });
        await tx.ledgerEntry.createMany({
          data: [
            {
              userId: transaction.userId,
              accountId: locked.id,
              transactionId: transaction.id,
              direction: LedgerDirection.DEBIT,
              amount: transaction.amount,
              balanceBefore: locked.balance,
              balanceAfter: lockedAfter,
              referenceType: 'WITHDRAWAL',
              referenceId: transaction.id,
              description: 'Withdrawal rejected',
            },
            {
              userId: transaction.userId,
              accountId: cash.id,
              transactionId: transaction.id,
              direction: LedgerDirection.CREDIT,
              amount: transaction.amount,
              balanceBefore: cash.balance,
              balanceAfter: cashAfter,
              referenceType: 'WITHDRAWAL',
              referenceId: transaction.id,
              description: 'Withdrawal funds returned',
            },
          ],
        });
      }

      const updated = await tx.financialTransaction.update({
        where: { id: transaction.id },
        data: {
          status: TransactionStatus.REJECTED,
          processedAt: new Date(),
          metadata: {
            ...((transaction.metadata as Record<string, unknown> | null) ?? {}),
            processedBy: actorUserId,
            rejectionReason: reason,
          },
        },
      });
      await tx.paymentIntent.updateMany({
        where: { transactionId: transaction.id },
        data: { status: PaymentIntentStatus.FAILED },
      });
      return updated;
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
  }

  async adjust(params: {
    userId: string;
    type: WalletType;
    currency?: string;
    amount: Prisma.Decimal | number;
    reason: string;
    actorUserId?: string;
    idempotencyKey?: string;
    referenceType?: string;
    referenceId?: string;
    transactionType?: TransactionType;
  }) {
    const amount = new Prisma.Decimal(params.amount);
    if (amount.isZero()) throw new BadRequestException('Amount cannot be zero');
    const currency = params.currency ?? 'MRU';
    return this.prisma.$transaction(async (tx) => {
      if (params.idempotencyKey) {
        const existing = await tx.financialTransaction.findUnique({ where: { idempotencyKey: params.idempotencyKey } });
        if (existing) return existing;
      }
      const account = await tx.walletAccount.findUnique({
        where: { userId_type_currency: { userId: params.userId, type: params.type, currency } },
      });
      if (!account) throw new NotFoundException('Wallet account not found');
      const after = account.balance.add(amount);
      if (after.isNegative()) throw new BadRequestException('Insufficient balance');
      const transaction = await tx.financialTransaction.create({
        data: {
          userId: params.userId,
          type: params.transactionType ?? TransactionType.ADMIN_ADJUSTMENT,
          status: TransactionStatus.COMPLETED,
          amount: amount.abs(),
          currency,
          idempotencyKey: params.idempotencyKey,
          description: params.reason,
          processedAt: new Date(),
          metadata: params.actorUserId ? { actorUserId: params.actorUserId } : undefined,
        },
      });
      await tx.walletAccount.update({ where: { id: account.id }, data: { balance: after, version: { increment: 1 } } });
      await tx.ledgerEntry.create({
        data: {
          userId: params.userId,
          accountId: account.id,
          transactionId: transaction.id,
          direction: amount.isPositive() ? LedgerDirection.CREDIT : LedgerDirection.DEBIT,
          amount: amount.abs(),
          balanceBefore: account.balance,
          balanceAfter: after,
          referenceType: params.referenceType,
          referenceId: params.referenceId,
          description: params.reason,
        },
      });
      return transaction;
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
  }

  private async settingNumber(key: string, fallback: number) {
    const setting = await this.prisma.appSetting.findUnique({ where: { key } });
    return typeof setting?.value === 'number' ? setting.value : fallback;
  }

  async transferBetweenTypes(
    userId: string,
    from: WalletType,
    to: WalletType,
    amountInput: number,
    referenceType: string,
    referenceId: string,
  ) {
    const amount = new Prisma.Decimal(amountInput);
    if (!amount.isPositive()) throw new BadRequestException('Amount must be positive');
    return this.prisma.$transaction(async (tx) => {
      const [source, target] = await Promise.all([
        tx.walletAccount.findUnique({ where: { userId_type_currency: { userId, type: from, currency: 'MRU' } } }),
        tx.walletAccount.findUnique({ where: { userId_type_currency: { userId, type: to, currency: 'MRU' } } }),
      ]);
      if (!source || !target || source.balance.lessThan(amount)) throw new BadRequestException('Insufficient balance');
      const transaction = await tx.financialTransaction.create({
        data: {
          userId,
          type: to === WalletType.LOCKED ? TransactionType.WAGER_LOCK : TransactionType.WAGER_RELEASE,
          status: TransactionStatus.COMPLETED,
          amount,
          description: referenceType,
          processedAt: new Date(),
        },
      });
      const sourceAfter = source.balance.sub(amount);
      const targetAfter = target.balance.add(amount);
      await tx.walletAccount.update({ where: { id: source.id }, data: { balance: sourceAfter, version: { increment: 1 } } });
      await tx.walletAccount.update({ where: { id: target.id }, data: { balance: targetAfter, version: { increment: 1 } } });
      await tx.ledgerEntry.createMany({
        data: [
          { userId, accountId: source.id, transactionId: transaction.id, direction: LedgerDirection.DEBIT, amount, balanceBefore: source.balance, balanceAfter: sourceAfter, referenceType, referenceId },
          { userId, accountId: target.id, transactionId: transaction.id, direction: LedgerDirection.CREDIT, amount, balanceBefore: target.balance, balanceAfter: targetAfter, referenceType, referenceId },
        ],
      });
      return transaction;
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
  }
}
