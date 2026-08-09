@echo off
cd /d %~dp0backend
if not exist .env copy .env.example .env
call npm install
call npm run db:generate
call npm run db:deploy
call npm run db:seed
call npm run start:dev
pause
