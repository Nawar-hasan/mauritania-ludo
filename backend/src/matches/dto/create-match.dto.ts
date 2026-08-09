import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsIn, IsInt, IsNumber, IsOptional, IsString, Min } from 'class-validator';
import { MatchMode } from '../../generated/prisma/client.js';
export class CreateMatchDto {
  @ApiProperty({ enum: MatchMode }) @IsEnum(MatchMode) mode: MatchMode;
  @ApiProperty({ enum: [2, 4] }) @IsInt() @IsIn([2, 4]) maxPlayers: number;
  @ApiProperty({ example: 'CLASSIC' }) @IsString() ruleCode: string;
  @ApiPropertyOptional() @IsOptional() @IsNumber({ maxDecimalPlaces: 4 }) @Min(0) stakeAmount?: number;
  @ApiPropertyOptional({ enum: ['MRU'] }) @IsOptional() @IsString() @IsIn(['MRU']) currency?: string;
}
