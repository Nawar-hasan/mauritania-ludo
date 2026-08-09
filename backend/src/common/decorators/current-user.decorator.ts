import { createParamDecorator, ExecutionContext } from '@nestjs/common';
export type AuthUser = { sub: string; username: string; roles: string[]; sessionId: string };
export const CurrentUser = createParamDecorator((_data: unknown, context: ExecutionContext): AuthUser => {
  return context.switchToHttp().getRequest().user as AuthUser;
});
