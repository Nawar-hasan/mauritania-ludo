import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsBoolean, IsHexColor, IsInt, IsObject, IsOptional, IsString, Min } from 'class-validator';

export class CreateStageDefinitionDto {
  @ApiProperty() @IsString() code: string;
  @ApiProperty() @IsString() nameAr: string;
  @ApiProperty() @IsString() nameEn: string;
  @ApiProperty() @Type(() => Number) @IsInt() @Min(1) minLevel: number;
  @ApiPropertyOptional() @IsOptional() @Type(() => Number) @IsInt() @Min(1) maxLevel?: number | null;
  @ApiPropertyOptional() @IsOptional() @IsString() imageUrl?: string;
  @ApiPropertyOptional() @IsOptional() @IsHexColor() colorHex?: string;
  @ApiPropertyOptional() @IsOptional() @IsObject() rewards?: Record<string, unknown>;
  @ApiPropertyOptional({ default: true }) @IsOptional() @IsBoolean() enabled?: boolean;
  @ApiPropertyOptional({ default: 0 }) @IsOptional() @Type(() => Number) @IsInt() sortOrder?: number;
}

export class UpdateStageDefinitionDto extends PartialType(CreateStageDefinitionDto) {}
