import { SegmentEnvelope, SyncFeedEntry } from "../domain/types.js";

export interface StoredSegmentEnvelope {
  accountID: string;
  segmentID: string;
  envelope: SegmentEnvelope;
  syncVersion: number;
  isDeleted: boolean;
  updatedAt: string;
}

export interface EnvelopeStore {
  get(accountID: string, segmentID: string): Promise<StoredSegmentEnvelope | null>;
  put(record: StoredSegmentEnvelope): Promise<void>;
}

export interface SyncFeedStore {
  append(entry: Omit<SyncFeedEntry, "feedPosition">): Promise<SyncFeedEntry>;
  listAfter(accountID: string, cursor?: string, limit?: number): Promise<{
    entries: SyncFeedEntry[];
    nextCursor: string;
    hasMore: boolean;
  }>;
}
