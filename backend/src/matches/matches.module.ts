import { Module } from '@nestjs/common';
import { MatchesController } from './matches.controller.js';
import { MatchesService } from './matches.service.js';
import { MatchesGateway } from './matches.gateway.js';
import { MatchTimeoutService } from './match-timeout.service.js';
@Module({ controllers: [MatchesController], providers: [MatchesService, MatchesGateway, MatchTimeoutService], exports: [MatchesService] })
export class MatchesModule {}
