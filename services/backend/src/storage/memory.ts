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

  async append(entry: SyncFeedEntry): Promise<void> {
    this.entries.push(entry);
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
}
