import { ConnectedSocket, MessageBody, SubscribeMessage, WebSocketGateway, WebSocketServer, WsException } from '@nestjs/websockets';
import { JwtService } from '@nestjs/jwt';
import { Server, Socket } from 'socket.io';
import { MatchesService } from './matches.service.js';
@WebSocketGateway({ namespace: '/matches', cors: { origin: true, credentials: true } })
export class MatchesGateway {
  @WebSocketServer() server: Server;
  constructor(private readonly matches: MatchesService, private readonly jwt: JwtService) {}
  async handleConnection(client: Socket) {
    try { client.data.user = await this.jwt.verifyAsync(client.handshake.auth?.token, { secret: process.env.JWT_ACCESS_SECRET! }); }
    catch { client.disconnect(true); }
  }
  @SubscribeMessage('join_match') async joinRoom(@ConnectedSocket() client: Socket, @MessageBody() data: { matchId: string }) { await this.matches.getForUser(data.matchId, client.data.user.sub); await client.join(`match:${data.matchId}`); return { ok: true }; }
  @SubscribeMessage('roll_dice') async roll(@ConnectedSocket() client: Socket, @MessageBody() data: { matchId: string }) { try { const match = await this.matches.roll(data.matchId, client.data.user.sub); this.server.to(`match:${data.matchId}`).emit('match_state', match); return match; } catch (e: any) { throw new WsException(e.message); } }
  @SubscribeMessage('move_piece') async move(@ConnectedSocket() client: Socket, @MessageBody() data: { matchId: string; pieceId: number; expectedVersion: number }) { try { const match = await this.matches.move(data.matchId, client.data.user.sub, data); this.server.to(`match:${data.matchId}`).emit('match_state', match); return match; } catch (e: any) { throw new WsException(e.message); } }
}
