import { BadRequestException, Injectable } from '@nestjs/common';
import { mkdir, writeFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { extname, join } from 'node:path';
import { PrismaService } from '../prisma/prisma.service.js';

@Injectable()
export class UploadsService {
  constructor(private readonly prisma: PrismaService) {}

  async avatar(userId: string, file?: Express.Multer.File) {
    const uploaded = await this.save(userId, file, 'avatars');
    await this.prisma.userProfile.update({ where: { userId }, data: { avatarUrl: uploaded.publicUrl } });
    return { avatarUrl: uploaded.publicUrl };
  }

  async receipt(userId: string, file?: Express.Multer.File) {
    const uploaded = await this.save(userId, file, 'receipts');
    return { url: uploaded.publicUrl, fileId: uploaded.id };
  }

  async asset(userId: string, file?: Express.Multer.File) {
    const uploaded = await this.save(userId, file, 'assets');
    return { url: uploaded.publicUrl, fileId: uploaded.id };
  }

  private async save(userId: string, file: Express.Multer.File | undefined, folder: string) {
    if (!file) throw new BadRequestException('File is required');
    const detectedMime = this.detectImageMime(file.buffer);
    const mimeType = ['image/jpeg', 'image/png', 'image/webp'].includes(file.mimetype)
      ? file.mimetype
      : detectedMime;
    if (!mimeType || !detectedMime || mimeType !== detectedMime) {
      throw new BadRequestException('Only valid JPEG, PNG and WEBP images are allowed');
    }
    const max = Number(process.env.MAX_UPLOAD_BYTES ?? 5_242_880);
    if (file.size > max) throw new BadRequestException('File is too large');

    const root = process.env.UPLOAD_DIR ?? 'uploads';
    const relativeDirectory = `${folder}/${userId}`;
    await mkdir(join(root, relativeDirectory), { recursive: true });
    const storageKey = `${relativeDirectory}/${randomUUID()}${extname(file.originalname).toLowerCase()}`;
    await writeFile(join(root, storageKey), file.buffer);
    const base = (process.env.PUBLIC_API_URL ?? 'http://localhost:3000').replace(/\/$/, '');
    const publicUrl = `${base}/uploads/${storageKey.replaceAll('\\', '/')}`;
    return this.prisma.uploadedFile.create({
      data: {
        userId,
        storageKey,
        originalName: file.originalname,
        mimeType,
        sizeBytes: file.size,
        publicUrl,
      },
    });
  }
  private detectImageMime(buffer: Buffer): 'image/jpeg' | 'image/png' | 'image/webp' | null {
    if (buffer.length >= 3 && buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) return 'image/jpeg';
    if (buffer.length >= 8 && buffer.subarray(0, 8).equals(Buffer.from([0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a]))) return 'image/png';
    if (buffer.length >= 12 && buffer.subarray(0,4).toString('ascii') === 'RIFF' && buffer.subarray(8,12).toString('ascii') === 'WEBP') return 'image/webp';
    return null;
  }

}
