import { IsDateString, IsIn, IsInt, IsNumber, IsOptional, IsString, Length, Max, Min } from 'class-validator';

export class CreateTournamentDto {
  @IsString() @Length(2, 40) code!: string;
  @IsString() @Length(2, 120) nameAr!: string;
  @IsString() @Length(2, 120) nameEn!: string;
  @IsOptional() @IsString() descriptionAr?: string;
  @IsOptional() @IsString() descriptionEn?: string;
  @IsOptional() @IsString() imageUrl?: string;
  @IsOptional() @IsString() ruleCode?: string;
  @IsOptional() @IsIn([2]) matchPlayers?: number;
  @IsOptional() @IsInt() @Min(2) @Max(128) minPlayers?: number;
  @IsOptional() @IsInt() @Min(2) @Max(128) maxPlayers?: number;
  @IsOptional() @IsNumber() @Min(0) entryFee?: number;
  @IsOptional() @IsString() @Length(3, 3) currency?: string;
  @IsOptional() @IsDateString() registrationOpensAt?: string;
  @IsOptional() @IsDateString() registrationClosesAt?: string;
  @IsOptional() @IsDateString() startsAt?: string;
  @IsOptional() @IsInt() sortOrder?: number;
}

export class TournamentStatusDto {
  @IsIn(['DRAFT','OPEN','ACTIVE','COMPLETED','CANCELLED']) status!: 'DRAFT'|'OPEN'|'ACTIVE'|'COMPLETED'|'CANCELLED';
}
