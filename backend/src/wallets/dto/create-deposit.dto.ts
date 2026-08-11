import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNumber, IsOptional, IsString, IsUUID, Matches, MaxLength, Min } from 'class-validator';

export class CreateDepositDto {
  @ApiProperty({ minimum: 1 })
  @IsNumber({ maxDecimalPlaces: 4 })
  @Min(1)
  amount: number;

  @ApiProperty({ description: 'Active payment method code configured by administration' })
  @IsString()
  @Matches(/^[A-Za-z0-9_-]{2,80}$/)
  method: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(120)
  externalRef?: string;


  @ApiPropertyOptional({ description: 'Private receipt file UUID returned by /users/me/receipt' })
  @IsOptional()
  @IsUUID()
  receiptFileId?: string;

  @ApiPropertyOptional({ deprecated: true, description: 'Legacy protected receipt URL; final clients should send receiptFileId' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  receiptUrl?: string;
}
