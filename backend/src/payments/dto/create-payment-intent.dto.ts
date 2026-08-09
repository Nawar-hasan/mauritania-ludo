import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNumber, IsOptional, IsString, Max, Min } from 'class-validator';

export class CreatePaymentIntentDto {
  @ApiProperty() @IsString() methodCode!: string;
  @ApiProperty() @IsNumber() @Min(1) @Max(100000000) amount!: number;
  @ApiPropertyOptional() @IsOptional() @IsString() phoneNumber?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() externalRef?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() receiptUrl?: string;
}
