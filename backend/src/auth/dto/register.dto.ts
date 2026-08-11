import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsEmail, IsIn, IsOptional, IsString, Length, Matches, MaxLength, MinLength } from 'class-validator';
export class RegisterDto {
  @ApiProperty() @IsString() @Length(3, 24) @Matches(/^[a-zA-Z0-9_]+$/) username: string;
  @ApiProperty() @IsString() @Length(2, 60) displayName: string;
  @ApiProperty() @IsEmail() email: string;
  @ApiPropertyOptional({ example: '+22212345678' }) @IsOptional() @Matches(/^\+?[0-9]{7,15}$/) phone?: string;
  @ApiProperty() @IsString() @MinLength(10) @MaxLength(128) password: string;
  @ApiProperty() @IsBoolean() acceptedTerms: boolean;
  @ApiPropertyOptional({ enum: ['ar', 'en'] }) @IsOptional() @IsIn(['ar', 'en']) locale?: string;
}
