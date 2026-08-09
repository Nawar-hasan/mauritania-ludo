import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString, MinLength } from 'class-validator';
export class LoginDto {
  @ApiProperty({ description: 'Username, email or phone' }) @IsString() identifier: string;
  @ApiProperty() @IsString() @MinLength(1) password: string;
  @ApiPropertyOptional() @IsOptional() @IsString() deviceId?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() deviceName?: string;
}
