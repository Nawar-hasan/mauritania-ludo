import { ApiProperty } from '@nestjs/swagger';
import { IsInt, Min } from 'class-validator';
export class MoveDto { @ApiProperty() @IsInt() @Min(0) pieceId: number; @ApiProperty() @IsInt() @Min(1) expectedVersion: number; }
