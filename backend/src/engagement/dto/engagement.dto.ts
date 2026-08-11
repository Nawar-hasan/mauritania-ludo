import { IsBoolean, IsDateString, IsIn, IsInt, IsOptional, IsString, IsUUID, Length, Matches, Max, Min } from 'class-validator';

export class ApplyReferralDto {
  @IsString() @Length(4, 32) code!: string;
}

export class UpdatePrivacyDto {
  @IsOptional() @IsBoolean() showOnlineStatus?: boolean;
  @IsOptional() @IsBoolean() allowDirectMessages?: boolean;
  @IsOptional() @IsBoolean() allowInvites?: boolean;
}

export class SubmitIdentityDto {
  @IsString() @Length(2, 100) legalName!: string;
  @IsDateString() dateOfBirth!: string;
  @IsString() @Length(2, 3) @Matches(/^[A-Za-z]{2,3}$/) countryCode!: string;
  @IsUUID() documentFrontFileId!: string;
  @IsOptional() @IsUUID() documentBackFileId?: string;
  @IsUUID() selfieFileId!: string;
}

export class ReviewIdentityDto {
  @IsIn(['VERIFIED', 'REJECTED', 'PENDING']) status!: 'VERIFIED' | 'REJECTED' | 'PENDING';
  @IsOptional() @IsString() @Length(0, 500) note?: string;
}

export class UpsertAchievementDto {
  @IsString() @Length(2, 40) code!: string;
  @IsString() @Length(2, 100) titleAr!: string;
  @IsString() @Length(2, 100) titleEn!: string;
  @IsOptional() @IsString() descriptionAr?: string;
  @IsOptional() @IsString() descriptionEn?: string;
  @IsIn(['MATCHES', 'WINS', 'LEVEL', 'XP']) metric!: 'MATCHES' | 'WINS' | 'LEVEL' | 'XP';
  @IsInt() @Min(1) @Max(100000000) target!: number;
  @IsOptional() @IsInt() @Min(0) @Max(100000000) rewardCoins?: number;
  @IsOptional() @IsInt() @Min(0) @Max(1000000) rewardGems?: number;
  @IsOptional() @IsString() iconUrl?: string;
  @IsOptional() @IsInt() sortOrder?: number;
  @IsOptional() @IsBoolean() enabled?: boolean;
}
