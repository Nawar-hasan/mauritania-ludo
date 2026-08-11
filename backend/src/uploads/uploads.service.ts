import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { join } from 'node:path';
import { Role } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';

@Injectable()
export class UploadsService {
  constructor(private readonly prisma: PrismaService) {}

  async avatar(userId: string, file?: Express.Multer.File) {
    const uploaded = await this.save(userId, file, 'avatars', false);
    await this.prisma.userProfile.update({ where: { userId }, data: { avatarUrl: uploaded.publicUrl } });
    return { avatarUrl: uploaded.publicUrl };
  }

  async receipt(userId: string, file?: Express.Multer.File) {
    const uploaded = await this.save(userId, file, 'receipts', true);
    return { url: uploaded.publicUrl, fileId: uploaded.id };
  }

  async identityDocument(userId: string, file?: Express.Multer.File) {
    const uploaded = await this.save(userId, file, 'identity', true);
    return { url: uploaded.publicUrl, fileId: uploaded.id, originalName: uploaded.originalName };
  }

  async asset(userId: string, file?: Express.Multer.File) {
    const uploaded = await this.save(userId, file, 'assets', false);
    return { url: uploaded.publicUrl, fileId: uploaded.id };
  }

  async privateFile(requester: { sub: string; roles: string[] }, id: string) {
    const file = await this.prisma.uploadedFile.findUnique({ where: { id } });
    if (!file || !file.isPrivate) throw new NotFoundException('File not found');
    const roles = new Set(requester.roles as Role[]);
    const isOwner = file.userId === requester.sub;
    const isAdmin = roles.has(Role.ADMIN) || roles.has(Role.SUPER_ADMIN);
    const isFinance = roles.has(Role.FINANCE);
    const allowedStaff = file.storageKey.startsWith('identity/')
      ? isAdmin
      : file.storageKey.startsWith('receipts/')
        ? (isAdmin || isFinance)
        : isAdmin;
    if (!isOwner && !allowedStaff) throw new ForbiddenException();
    const root = process.env.PRIVATE_UPLOAD_DIR ?? join(process.env.UPLOAD_DIR ?? join(process.cwd(), 'uploads'), '_private');
    const bytes = await readFile(join(root, file.storageKey)).catch(() => null);
    if (!bytes) throw new NotFoundException('File not found');
    return { file, bytes };
  }

  private async save(userId: string, file: Express.Multer.File | undefined, folder: string, isPrivate: boolean) {
    if (!file) throw new BadRequestException('File is required');
    const detectedMime = this.detectImageMime(file.buffer);
    const mimeType = ['image/jpeg', 'image/png', 'image/webp'].includes(file.mimetype) ? file.mimetype : detectedMime;
    if (!mimeType || !detectedMime || mimeType !== detectedMime) throw new BadRequestException('Only valid JPEG, PNG and WEBP images are allowed');
    const max = Number(process.env.MAX_UPLOAD_BYTES ?? 5_242_880);
    if (file.size > max) throw new BadRequestException('File is too large');

    const extension = detectedMime === 'image/jpeg' ? '.jpg' : detectedMime === 'image/png' ? '.png' : '.webp';
    const root = isPrivate ? (process.env.PRIVATE_UPLOAD_DIR ?? join(process.env.UPLOAD_DIR ?? join(process.cwd(), 'uploads'), '_private')) : (process.env.UPLOAD_DIR ?? join(process.cwd(), 'uploads'));
    const relativeDirectory = `${folder}/${userId}`;
    await mkdir(join(root, relativeDirectory), { recursive: true });
    const storageKey = `${relativeDirectory}/${randomUUID()}${extension}`;
    await writeFile(join(root, storageKey), file.buffer);
    const base = (process.env.PUBLIC_API_URL ?? 'http://localhost:3000').replace(/\/$/, '');
    const created = await this.prisma.uploadedFile.create({ data: {
      userId, storageKey, originalName: file.originalname.replace(/[\r\n]/g, '').slice(0, 180), mimeType, sizeBytes: file.size, publicUrl: '', isPrivate,
    } });
    const publicUrl = isPrivate ? `${base}/api/v1/files/${created.id}` : `${base}/uploads/${storageKey.replaceAll('\\', '/')}`;
    return this.prisma.uploadedFile.update({ where: { id: created.id }, data: { publicUrl } });
  }

  private detectImageMime(buffer: Buffer): 'image/jpeg' | 'image/png' | 'image/webp' | null {
    if (buffer.length >= 3 && buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) return 'image/jpeg';
    if (buffer.length >= 8 && buffer.subarray(0, 8).equals(Buffer.from([0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a]))) return 'image/png';
    if (buffer.length >= 12 && buffer.subarray(0,4).toString('ascii') === 'RIFF' && buffer.subarray(8,12).toString('ascii') === 'WEBP') return 'image/webp';
    return null;
  }
}
