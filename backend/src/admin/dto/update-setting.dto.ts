import { ApiProperty } from '@nestjs/swagger';
import { IsDefined, IsOptional, IsString } from 'class-validator';
export class UpdateSettingDto { @ApiProperty() @IsDefined() value: unknown; @ApiProperty({ required: false }) @IsOptional() @IsString() description?: string; }
