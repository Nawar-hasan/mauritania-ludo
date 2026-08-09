import { Injectable, OnModuleDestroy } from '@nestjs/common';
import { Redis } from 'ioredis';
import { randomUUID } from 'node:crypto';
@Injectable()
export class RedisService implements OnModuleDestroy {
  readonly client = new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379', { maxRetriesPerRequest: 2 });
  ping() { return this.client.ping(); }
  async onModuleDestroy() { await this.client.quit(); }
  async withLock<T>(key: string, ttlMs: number, action: () => Promise<T>): Promise<T> {
    const token = randomUUID();
    const acquired = await this.client.set(`lock:${key}`, token, 'PX', ttlMs, 'NX');
    if (!acquired) throw new Error('Resource is busy');
    try { return await action(); }
    finally {
      const current = await this.client.get(`lock:${key}`);
      if (current === token) await this.client.del(`lock:${key}`);
    }
  }
}
