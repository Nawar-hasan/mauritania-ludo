import { IsString, Length, MaxLength, MinLength } from 'class-validator';

export class RequestPasswordResetDto {
  @IsString() @MinLength(3) @MaxLength(160) identifier!: string;
}

export class VerifyPasswordResetDto {
  @IsString() @Length(36, 36) requestId!: string;
  @IsString() @Length(6, 6) code!: string;
}

export class CompletePasswordResetDto {
  @IsString() @Length(36, 36) requestId!: string;
  @IsString() @MinLength(32) @MaxLength(256) resetToken!: string;
  @IsString() @MinLength(10) @MaxLength(128) newPassword!: string;
}
