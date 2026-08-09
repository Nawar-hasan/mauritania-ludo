import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsBoolean, IsInt, IsOptional, IsUUID, Max, Min } from 'class-validator';

export class GrantCatalogItemDto {
  @ApiProperty() @IsUUID() itemId!: string;
  @ApiPropertyOptional({ default: 1 }) @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(9999) quantity?: number;
  @ApiPropertyOptional({ default: false }) @IsOptional() @IsBoolean() equip?: boolean;
}
