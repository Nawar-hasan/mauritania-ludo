import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNumber, IsOptional, IsString, IsUUID, Max, MaxLength, Min } from 'class-validator';

export class CreatePaymentIntentDto {
  @ApiProperty() @IsString() methodCode!: string;
  @ApiProperty() @IsNumber() @Min(1) @Max(100000000) amount!: number;
  @ApiPropertyOptional() @IsOptional() @IsString() phoneNumber?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() externalRef?: string;
  @ApiPropertyOptional() @IsOptional() @IsUUID() receiptFileId?: string;
  @ApiPropertyOptional({ deprecated: true }) @IsOptional() @IsString() @MaxLength(500) receiptUrl?: string;
}
