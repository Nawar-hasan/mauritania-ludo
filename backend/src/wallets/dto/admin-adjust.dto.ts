import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsNumber, IsOptional, IsString, IsUUID, Min, MinLength } from 'class-validator';
import { WalletType } from '../../generated/prisma/client.js';
export class AdminAdjustDto {
  @ApiProperty() @IsUUID() userId: string;
  @ApiProperty({ enum: WalletType }) @IsEnum(WalletType) accountType: WalletType;
  @ApiProperty({ description: 'Positive credits, negative debits' }) @IsNumber({ maxDecimalPlaces: 4 }) amount: number;
  @ApiPropertyOptional() @IsOptional() @IsString() currency?: string;
  @ApiProperty() @IsString() @MinLength(3) reason: string;
  @ApiPropertyOptional() @IsOptional() @IsString() idempotencyKey?: string;
}
