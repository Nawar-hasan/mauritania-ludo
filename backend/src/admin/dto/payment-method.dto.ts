import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsBoolean, IsEnum, IsInt, IsNumber, IsObject, IsOptional, IsString, Min } from 'class-validator';
import { PaymentMethodStatus, PaymentProvider } from '../../generated/prisma/client.js';
export class CreatePaymentMethodDto {
  @ApiProperty() @IsString() code!: string;
  @ApiProperty({ enum: PaymentProvider }) @IsEnum(PaymentProvider) provider!: PaymentProvider;
  @ApiProperty() @IsString() nameAr!: string;
  @ApiProperty() @IsString() nameEn!: string;
  @ApiPropertyOptional({ enum: PaymentMethodStatus }) @IsOptional() @IsEnum(PaymentMethodStatus) status?: PaymentMethodStatus;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() supportsDeposit?: boolean;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() supportsWithdrawal?: boolean;
  @ApiPropertyOptional() @IsOptional() @IsString() currency?: string;
  @ApiPropertyOptional() @IsOptional() @Type(() => Number) @IsNumber() @Min(0) minAmount?: number;
  @ApiPropertyOptional() @IsOptional() @Type(() => Number) @IsNumber() @Min(0) maxAmount?: number;
  @ApiPropertyOptional() @IsOptional() @Type(() => Number) @IsNumber() @Min(0) feeFixed?: number;
  @ApiPropertyOptional() @IsOptional() @Type(() => Number) @IsNumber() @Min(0) feeRate?: number;
  @ApiPropertyOptional() @IsOptional() @IsString() iconUrl?: string;
  @ApiPropertyOptional() @IsOptional() @IsObject() publicConfig?: Record<string, unknown>;
  @ApiPropertyOptional() @IsOptional() @IsString() secretEnvPrefix?: string;
  @ApiPropertyOptional() @IsOptional() @Type(() => Number) @IsInt() sortOrder?: number;
}
export class UpdatePaymentMethodDto extends PartialType(CreatePaymentMethodDto) {}
