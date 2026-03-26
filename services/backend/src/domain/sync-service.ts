import { validatePushChange } from "./validation";
import {
  PullRequest,
  PullResponse,
  PushRequest,
  PushResponse,
  SegmentEnvelope,
  ValidationErrorPayload,
} from "./types";
import { EnvelopeStore, StoredSegmentEnvelope, SyncFeedStore } from "../storage/interfaces";

export class SyncService {
  constructor(
    private readonly envelopeStore: EnvelopeStore,
    private readonly feedStore: SyncFeedStore
  ) {}

  async push(request: PushRequest): Promise<PushResponse | ValidationErrorPayload> {
    const accepted: PushResponse["accepted"] = [];
    const conflicts: PushResponse["conflicts"] = [];

    for (const change of request.changes) {
      const validationError = validatePushChange(change);
      if (validationError) {
        return validationError;
      }

      const envelope = change.segmentEnvelope;
      const existing = await this.envelopeStore.get(request.accountID, envelope.segment.id);

      if (existing && change.baseSyncVersion !== existing.syncVersion) {
        conflicts.push({
          segmentID: envelope.segment.id,
          reason: existing.isDeleted ? "deletedOnServer" : "versionMismatch",
          serverEnvelope: existing.envelope,
        });
        continue;
      }

      const nextVersion = existing ? existing.syncVersion + 1 : 1;
      const acceptedEnvelope = this.withServerVersion(envelope, nextVersion);
      const stored: StoredSegmentEnvelope = {
        accountID: request.accountID,
        segmentID: acceptedEnvelope.segment.id,
        envelope: acceptedEnvelope,
        syncVersion: nextVersion,
        isDeleted: acceptedEnvelope.sync.isDeleted,
        updatedAt: acceptedEnvelope.sync.lastModifiedAt,
      };

      await this.envelopeStore.put(stored);
      await this.feedStore.append({
        accountID: request.accountID,
        feedPosition: this.feedPositionFromVersion(nextVersion, acceptedEnvelope.segment.id),
        segmentID: acceptedEnvelope.segment.id,
        syncVersion: nextVersion,
        changedAt: acceptedEnvelope.sync.lastModifiedAt,
        isDeleted: acceptedEnvelope.sync.isDeleted,
      });

      accepted.push({
        segmentID: acceptedEnvelope.segment.id,
        syncVersion: nextVersion,
        updatedAt: acceptedEnvelope.sync.lastModifiedAt,
      });
    }

    return { accepted, conflicts };
  }

  async pull(request: PullRequest): Promise<PullResponse> {
    const page = await this.feedStore.listAfter(request.accountID, request.cursor);
    const changes: PullResponse["changes"] = [];

    for (const entry of page.entries) {
      const stored = await this.envelopeStore.get(request.accountID, entry.segmentID);
      if (!stored) continue;
      changes.push({ segmentEnvelope: stored.envelope });
    }

    return {
      changes,
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
    };
  }

  private withServerVersion(envelope: SegmentEnvelope, syncVersion: number): SegmentEnvelope {
    return {
      ...envelope,
      sync: {
        ...envelope.sync,
        syncVersion,
      },
    };
  }

  // Placeholder monotonic feed position until real storage supplies one.
  private feedPositionFromVersion(syncVersion: number, segmentID: string): number {
    const suffix = Number.parseInt(segmentID.replace(/[^0-9]/g, "").slice(-6) || "0", 10);
    return syncVersion * 1_000_000 + suffix;
  }
}
