import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsBoolean, IsInt, IsOptional, IsString, Matches, Max, Min } from 'class-validator';

export class CreateGameRuleSetDto {
  @ApiProperty({ example: 'CLASSIC_PLUS' }) @IsString() @Matches(/^[A-Z0-9_]{2,40}$/) code: string;
  @ApiProperty() @IsString() name: string;
  @ApiPropertyOptional() @IsOptional() @IsString() descriptionAr?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() descriptionEn?: string;
  @ApiPropertyOptional({ default: 0 }) @IsOptional() @Type(() => Number) @IsInt() sortOrder?: number;
  @ApiPropertyOptional({ default: 4 }) @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(4) piecesPerPlayer?: number;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() requiresSixToExit?: boolean;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() extraTurnOnSix?: boolean;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() extraTurnOnCapture?: boolean;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() extraTurnOnFinish?: boolean;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() threeSixesLoseTurn?: boolean;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() exactRollToFinish?: boolean;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() blockadeEnabled?: boolean;
  @ApiPropertyOptional() @IsOptional() @Type(() => Number) @IsInt() @Min(5) @Max(60) rollSeconds?: number;
  @ApiPropertyOptional() @IsOptional() @Type(() => Number) @IsInt() @Min(5) @Max(60) moveSeconds?: number;
  @ApiPropertyOptional() @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(5) maxInactiveTurns?: number;
  @ApiPropertyOptional() @IsOptional() @Type(() => Number) @IsInt() @Min(5) @Max(180) reconnectSeconds?: number;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() finishAllPlayers?: boolean;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() enabled?: boolean;
}

export class UpdateGameRuleSetDto extends PartialType(CreateGameRuleSetDto) {}
