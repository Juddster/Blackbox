import { SyncFeedEntry } from "../domain/types";
import { EnvelopeStore, StoredSegmentEnvelope, SyncFeedStore } from "./interfaces";

export class InMemoryEnvelopeStore implements EnvelopeStore {
  private readonly records = new Map<string, StoredSegmentEnvelope>();

  async get(accountID: string, segmentID: string): Promise<StoredSegmentEnvelope | null> {
    return this.records.get(this.key(accountID, segmentID)) ?? null;
  }

  async put(record: StoredSegmentEnvelope): Promise<void> {
    this.records.set(this.key(record.accountID, record.segmentID), record);
  }

  private key(accountID: string, segmentID: string): string {
    return `${accountID}:${segmentID}`;
  }
}

export class InMemorySyncFeedStore implements SyncFeedStore {
  private readonly entries: SyncFeedEntry[] = [];
  private readonly nextFeedPositionByAccount = new Map<string, number>();

  async append(entry: Omit<SyncFeedEntry, "feedPosition">): Promise<SyncFeedEntry> {
    const nextFeedPosition = this.nextFeedPosition(entry.accountID);
    const storedEntry: SyncFeedEntry = {
      ...entry,
      feedPosition: nextFeedPosition,
    };
    this.entries.push(storedEntry);
    return storedEntry;
  }

  async listAfter(accountID: string, cursor?: string, limit = 100): Promise<{
    entries: SyncFeedEntry[];
    nextCursor: string;
    hasMore: boolean;
  }> {
    const accountEntries = this.entries.filter((entry) => entry.accountID === accountID);
    const cursorPosition = cursor ? Number.parseInt(cursor, 10) : 0;
    const filtered = accountEntries.filter((entry) => entry.feedPosition > cursorPosition);
    const page = filtered.slice(0, limit);
    const lastPosition = page.length > 0 ? page[page.length - 1].feedPosition : cursorPosition;

    return {
      entries: page,
      nextCursor: String(lastPosition),
      hasMore: filtered.length > page.length,
    };
  }

  private nextFeedPosition(accountID: string): number {
    const next = (this.nextFeedPositionByAccount.get(accountID) ?? 0) + 1;
    this.nextFeedPositionByAccount.set(accountID, next);
    return next;
  }
}
