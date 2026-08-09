import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEmail, IsIn, IsOptional, IsString, Length, Matches, MinLength } from 'class-validator';
export class RegisterDto {
  @ApiProperty() @IsString() @Length(3, 24) @Matches(/^[a-zA-Z0-9_]+$/) username: string;
  @ApiProperty() @IsString() @Length(2, 60) displayName: string;
  @ApiPropertyOptional() @IsOptional() @IsEmail() email?: string;
  @ApiPropertyOptional({ example: '+22212345678' }) @IsOptional() @Matches(/^\+?[0-9]{7,15}$/) phone?: string;
  @ApiProperty() @IsString() @MinLength(10) password: string;
  @ApiPropertyOptional({ enum: ['ar', 'en'] }) @IsOptional() @IsIn(['ar', 'en']) locale?: string;
}
