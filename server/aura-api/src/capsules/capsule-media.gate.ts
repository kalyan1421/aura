import { Injectable } from '@nestjs/common';
import { ApiError } from '../common/api-error';
import { DbService } from '../db/db.service';
import { capsuleIdOfPath } from '../media/media-paths';
import { CapsulesRepository } from './capsules.repository';

export const capsuleSealed = (): ApiError =>
  ApiError.conflict('capsule_sealed', 'This capsule is sealed: its media cannot change (the slot is already uploaded).');
export const capsuleDeleted = (): ApiError => ApiError.conflict('capsule_deleted', 'This capsule was deleted.');

/**
 * "Sealed means sealed" for capsule media (contracts/api/v1-capsules.md §5). Before the seal reaches the server a
 * slot's upload URL is an upsert (retries overwrite); once sealed, an empty slot may still be filled once, an
 * occupied slot is `409 capsule_sealed`; a deleted capsule is `409 capsule_deleted` (and its paths never download).
 */
@Injectable()
export class CapsuleMediaGate {
  constructor(
    private readonly db: DbService,
    private readonly repo: CapsulesRepository,
  ) {}

  async checkUpload(userId: string, capsuleId: string, path: string): Promise<void> {
    const state = await this.repo.state(this.db, userId, capsuleId);
    if (state === 'deleted') throw capsuleDeleted();
    if (state === 'live' && (await this.repo.objectExists(this.db, path))) throw capsuleSealed();
  }

  /** True for a path of one of the caller's deleted capsules (downloads answer 404 like any missing object). */
  async isDeletedCapsulePath(userId: string, path: string): Promise<boolean> {
    const id = capsuleIdOfPath(userId, path);
    return id !== null && (await this.repo.state(this.db, userId, id)) === 'deleted';
  }
}
