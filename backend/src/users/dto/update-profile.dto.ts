import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsOptional, IsString, Length, MaxLength } from 'class-validator';
export class UpdateProfileDto {
  @ApiPropertyOptional() @IsOptional() @IsString() @Length(2, 60) displayName?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(250) bio?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @Length(2, 2) countryCode?: string;
  @ApiPropertyOptional({ enum: ['ar', 'en'] }) @IsOptional() @IsIn(['ar', 'en']) locale?: string;
}
