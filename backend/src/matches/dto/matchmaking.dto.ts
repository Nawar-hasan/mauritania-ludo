import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsIn, IsInt, IsNumber, IsOptional, IsString, Min } from 'class-validator';
import { MatchMode } from '../../generated/prisma/client.js';
export class MatchmakingDto {
  @ApiProperty({ enum: [2, 4] }) @IsInt() @IsIn([2, 4]) maxPlayers: number;
  @ApiProperty({ enum: [MatchMode.CASUAL, MatchMode.WAGER] }) @IsEnum(MatchMode) mode: MatchMode;
  @ApiProperty() @IsString() ruleCode: string;
  @ApiPropertyOptional() @IsOptional() @IsNumber({ maxDecimalPlaces: 4 }) @Min(0) stakeAmount?: number;
}
