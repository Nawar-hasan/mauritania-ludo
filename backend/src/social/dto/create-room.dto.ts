import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsInt, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';
import { SocialRoomType, SocialRoomVisibility } from '../../generated/prisma/client.js';

export class CreateRoomDto {
  @ApiProperty() @IsString() @MaxLength(60) name!: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(240) description?: string;
  @ApiProperty({ enum: SocialRoomType }) @IsEnum(SocialRoomType) type!: SocialRoomType;
  @ApiPropertyOptional({ enum: SocialRoomVisibility }) @IsOptional() @IsEnum(SocialRoomVisibility) visibility?: SocialRoomVisibility;
  @ApiPropertyOptional({ minimum: 2, maximum: 50 }) @IsOptional() @IsInt() @Min(2) @Max(50) maxParticipants?: number;
}
