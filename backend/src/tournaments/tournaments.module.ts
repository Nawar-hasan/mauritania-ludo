import { Module } from '@nestjs/common';
import { TournamentsController, TournamentsAdminController } from './tournaments.controller.js';
import { TournamentsService } from './tournaments.service.js';
@Module({ controllers: [TournamentsController, TournamentsAdminController], providers: [TournamentsService] })
export class TournamentsModule {}
