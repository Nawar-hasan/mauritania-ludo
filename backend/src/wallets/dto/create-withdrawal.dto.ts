import { ApiProperty } from '@nestjs/swagger';
import { IsNumber, IsString, Length, Matches, MaxLength, Min } from 'class-validator';

export class CreateWithdrawalDto {
  @ApiProperty({ minimum: 1 })
  @IsNumber({ maxDecimalPlaces: 4 })
  @Min(1)
  amount: number;

  @ApiProperty({ description: 'Active withdrawal method code configured by administration' })
  @IsString()
  @Matches(/^[A-Za-z0-9_-]{2,80}$/)
  method: string;

  @ApiProperty()
  @IsString()
  @Length(3, 120)
  accountNumber: string;

  @ApiProperty()
  @IsString()
  @Length(2, 120)
  accountName: string;

  @ApiProperty()
  @IsString()
  @MaxLength(300)
  note: string;
}
