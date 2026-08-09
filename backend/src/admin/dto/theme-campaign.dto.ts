import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsBoolean, IsDateString, IsEnum, IsInt, IsObject, IsOptional, IsString } from 'class-validator';
import { CampaignSurface } from '../../generated/prisma/client.js';
export class CreateThemeCampaignDto {
  @ApiProperty() @IsString() code!: string;
  @ApiProperty({ enum: CampaignSurface }) @IsEnum(CampaignSurface) surface!: CampaignSurface;
  @ApiProperty() @IsString() nameAr!: string;
  @ApiProperty() @IsString() nameEn!: string;
  @ApiPropertyOptional() @IsOptional() @IsString() imageUrl?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() backgroundColor?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() textColor?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() actionType?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() actionValue?: string;
  @ApiPropertyOptional() @IsOptional() @IsDateString() startsAt?: string;
  @ApiPropertyOptional() @IsOptional() @IsDateString() endsAt?: string;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() enabled?: boolean;
  @ApiPropertyOptional() @IsOptional() @Type(() => Number) @IsInt() priority?: number;
  @ApiPropertyOptional() @IsOptional() @IsObject() metadata?: Record<string, unknown>;
}
export class UpdateThemeCampaignDto extends PartialType(CreateThemeCampaignDto) {}
