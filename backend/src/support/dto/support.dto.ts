import { IsIn, IsInt, IsOptional, IsString, Length, Max, Min } from 'class-validator';

export class CreateSupportTicketDto {
  @IsString() @Length(3, 120) subject!: string;
  @IsString() @Length(2, 40) category!: string;
  @IsString() @Length(2, 2000) message!: string;
  @IsOptional() @IsInt() @Min(1) @Max(3) priority?: number;
}

export class SupportMessageDto {
  @IsString() @Length(1, 2000) text!: string;
}

export class UpdateSupportStatusDto {
  @IsIn(['OPEN','IN_PROGRESS','WAITING_USER','RESOLVED','CLOSED']) status!: 'OPEN'|'IN_PROGRESS'|'WAITING_USER'|'RESOLVED'|'CLOSED';
}
