import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsBoolean, IsInt, IsObject, IsOptional, IsString, Min } from 'class-validator';
export class CreateLevelDefinitionDto {
  @ApiProperty() @Type(() => Number) @IsInt() @Min(1) level!: number;
  @ApiProperty() @Type(() => Number) @IsInt() @Min(0) xpRequired!: number;
  @ApiProperty() @IsString() titleAr!: string;
  @ApiProperty() @IsString() titleEn!: string;
  @ApiPropertyOptional() @IsOptional() @IsString() badgeUrl?: string;
  @ApiPropertyOptional() @IsOptional() @IsObject() rewards?: Record<string, unknown>;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() enabled?: boolean;
}
export class UpdateLevelDefinitionDto extends PartialType(CreateLevelDefinitionDto) {}
