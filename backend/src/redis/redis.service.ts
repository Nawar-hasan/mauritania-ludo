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
      await this.client.eval(
        "if redis.call('GET', KEYS[1]) == ARGV[1] then return redis.call('DEL', KEYS[1]) else return 0 end",
        1, `lock:${key}`, token,
      );
    }
  }

  async rateLimit(key: string, limit: number, windowSeconds: number) {
    const redisKey = `rate:${key}`;
    const result = await this.client.eval(
      "local current = redis.call('INCR', KEYS[1]); if current == 1 then redis.call('EXPIRE', KEYS[1], ARGV[1]); end; local ttl = redis.call('TTL', KEYS[1]); return {current, ttl};",
      1, redisKey, windowSeconds,
    ) as [number, number];
    const count = Number(result?.[0] ?? 1);
    const ttl = Number(result?.[1] ?? windowSeconds);
    return { allowed: count <= limit, count, retryAfter: Math.max(1, ttl) };
  }

  clearRateLimit(key: string) { return this.client.del(`rate:${key}`); }
}
