import { ConnectedSocket, MessageBody, SubscribeMessage, WebSocketGateway, WebSocketServer, WsException } from '@nestjs/websockets';
import { JwtService } from '@nestjs/jwt';
import { Server, Socket } from 'socket.io';
import { MatchesService } from './matches.service.js';
const socketOrigins = (process.env.CORS_ORIGINS ?? 'http://localhost:3001').split(',').map((x) => x.trim()).filter(Boolean);

@WebSocketGateway({ namespace: '/matches', cors: { origin: socketOrigins, credentials: true } })
export class MatchesGateway {
  @WebSocketServer() server: Server;
  constructor(private readonly matches: MatchesService, private readonly jwt: JwtService) {}
  async handleConnection(client: Socket) {
    try { client.data.user = await this.jwt.verifyAsync(client.handshake.auth?.token, { secret: process.env.JWT_ACCESS_SECRET! }); }
    catch { client.disconnect(true); }
  }
  @SubscribeMessage('join_match') async joinRoom(@ConnectedSocket() client: Socket, @MessageBody() data: { matchId: string }) { const userId = client.data.user?.sub; if (!userId) throw new WsException('Unauthorized'); await this.matches.getForUser(data.matchId, userId); await client.join(`match:${data.matchId}`); return { ok: true }; }
  @SubscribeMessage('roll_dice') async roll(@ConnectedSocket() client: Socket, @MessageBody() data: { matchId: string }) { try { const userId = client.data.user?.sub; if (!userId) throw new WsException('Unauthorized'); const match = await this.matches.roll(data.matchId, userId); this.server.to(`match:${data.matchId}`).emit('match_state', match); return match; } catch (e: any) { throw e instanceof WsException ? e : new WsException(e.message); } }
  @SubscribeMessage('move_piece') async move(@ConnectedSocket() client: Socket, @MessageBody() data: { matchId: string; pieceId: number; expectedVersion: number }) { try { const userId = client.data.user?.sub; if (!userId) throw new WsException('Unauthorized'); const match = await this.matches.move(data.matchId, userId, data); this.server.to(`match:${data.matchId}`).emit('match_state', match); return match; } catch (e: any) { throw e instanceof WsException ? e : new WsException(e.message); } }
}
