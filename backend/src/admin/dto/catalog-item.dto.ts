import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsBoolean, IsEnum, IsInt, IsNumber, IsObject, IsOptional, IsString, Max, Min } from 'class-validator';
import { CatalogItemType, CatalogRarity, CatalogStatus, WalletType } from '../../generated/prisma/client.js';

export class CreateCatalogItemDto {
  @ApiProperty() @IsString() code!: string;
  @ApiProperty({ enum: CatalogItemType }) @IsEnum(CatalogItemType) type!: CatalogItemType;
  @ApiProperty() @IsString() nameAr!: string;
  @ApiProperty() @IsString() nameEn!: string;
  @ApiPropertyOptional() @IsOptional() @IsString() descriptionAr?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() descriptionEn?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() imageUrl?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() previewUrl?: string;
  @ApiPropertyOptional({ default: 0 }) @IsOptional() @Type(() => Number) @IsNumber() @Min(0) price?: number;
  @ApiPropertyOptional({ enum: WalletType, default: WalletType.COINS }) @IsOptional() @IsEnum(WalletType) priceWallet?: WalletType;
  @ApiPropertyOptional({ default: 1 }) @IsOptional() @Type(() => Number) @IsInt() @Min(1) minLevel?: number;
  @ApiPropertyOptional({ enum: CatalogRarity }) @IsOptional() @IsEnum(CatalogRarity) rarity?: CatalogRarity;
  @ApiPropertyOptional({ enum: CatalogStatus }) @IsOptional() @IsEnum(CatalogStatus) status?: CatalogStatus;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() isFeatured?: boolean;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() isDefault?: boolean;
  @ApiPropertyOptional() @IsOptional() @Type(() => Number) @IsInt() @Min(-10000) @Max(10000) sortOrder?: number;
  @ApiPropertyOptional() @IsOptional() @IsObject() metadata?: Record<string, unknown>;
}
export class UpdateCatalogItemDto extends PartialType(CreateCatalogItemDto) {}
