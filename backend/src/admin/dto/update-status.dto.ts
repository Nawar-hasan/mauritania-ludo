import { ApiProperty } from '@nestjs/swagger';
import { IsEnum, IsString, MinLength } from 'class-validator';
import { UserStatus } from '../../generated/prisma/client.js';
export class UpdateStatusDto { @ApiProperty({ enum: UserStatus }) @IsEnum(UserStatus) status: UserStatus; @ApiProperty() @IsString() @MinLength(3) reason: string; }
