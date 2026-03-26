import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { SyncFeedEntry } from "../domain/types.js";
import { EnvelopeStore, StoredSegmentEnvelope, SyncFeedStore } from "./interfaces.js";

interface FileStorageSnapshot {
  envelopes: StoredSegmentEnvelope[];
  feedEntries: SyncFeedEntry[];
}

const EMPTY_SNAPSHOT: FileStorageSnapshot = {
  envelopes: [],
  feedEntries: [],
};

async function ensureStorageDir(storageDir: string): Promise<void> {
  await mkdir(storageDir, { recursive: true });
}

async function readSnapshot(snapshotPath: string): Promise<FileStorageSnapshot> {
  try {
    const raw = await readFile(snapshotPath, "utf8");
    const parsed = JSON.parse(raw) as Partial<FileStorageSnapshot>;
    return {
      envelopes: Array.isArray(parsed.envelopes) ? parsed.envelopes : [],
      feedEntries: Array.isArray(parsed.feedEntries) ? parsed.feedEntries : [],
    };
  } catch (error) {
    const nodeError = error as NodeJS.ErrnoException;
    if (nodeError.code === "ENOENT") {
      return EMPTY_SNAPSHOT;
    }
    throw error;
  }
}

async function writeSnapshot(snapshotPath: string, snapshot: FileStorageSnapshot): Promise<void> {
  await writeFile(snapshotPath, JSON.stringify(snapshot, null, 2) + "\n", "utf8");
}

class FileStorageCoordinator {
  readonly snapshotPath: string;

  constructor(storageDir: string) {
    this.snapshotPath = path.join(storageDir, "sync-state.json");
  }

  async update<T>(mutate: (snapshot: FileStorageSnapshot) => T | Promise<T>): Promise<T> {
    await ensureStorageDir(path.dirname(this.snapshotPath));
    const snapshot = await readSnapshot(this.snapshotPath);
    const result = await mutate(snapshot);
    await writeSnapshot(this.snapshotPath, snapshot);
    return result;
  }

  async read<T>(project: (snapshot: FileStorageSnapshot) => T | Promise<T>): Promise<T> {
    await ensureStorageDir(path.dirname(this.snapshotPath));
    const snapshot = await readSnapshot(this.snapshotPath);
    return project(snapshot);
  }
}

export class FileEnvelopeStore implements EnvelopeStore {
  constructor(private readonly coordinator: FileStorageCoordinator) {}

  async get(accountID: string, segmentID: string): Promise<StoredSegmentEnvelope | null> {
    return this.coordinator.read((snapshot) => {
      return snapshot.envelopes.find((record) => record.accountID === accountID && record.segmentID === segmentID) ?? null;
    });
  }

  async put(record: StoredSegmentEnvelope): Promise<void> {
    await this.coordinator.update((snapshot) => {
      const existingIndex = snapshot.envelopes.findIndex(
        (candidate) => candidate.accountID === record.accountID && candidate.segmentID === record.segmentID
      );

      if (existingIndex >= 0) {
        snapshot.envelopes[existingIndex] = record;
      } else {
        snapshot.envelopes.push(record);
      }
    });
  }
}

export class FileSyncFeedStore implements SyncFeedStore {
  constructor(private readonly coordinator: FileStorageCoordinator) {}

  async append(entry: Omit<SyncFeedEntry, "feedPosition">): Promise<SyncFeedEntry> {
    return this.coordinator.update((snapshot) => {
      const accountEntries = snapshot.feedEntries.filter((candidate) => candidate.accountID === entry.accountID);
      const nextFeedPosition = (accountEntries[accountEntries.length - 1]?.feedPosition ?? 0) + 1;
      const storedEntry: SyncFeedEntry = {
        ...entry,
        feedPosition: nextFeedPosition,
      };
      snapshot.feedEntries.push(storedEntry);
      return storedEntry;
    });
  }

  async listAfter(accountID: string, cursor?: string, limit = 100): Promise<{
    entries: SyncFeedEntry[];
    nextCursor: string;
    hasMore: boolean;
  }> {
    return this.coordinator.read((snapshot) => {
      const accountEntries = snapshot.feedEntries.filter((entry) => entry.accountID === accountID);
      const cursorPosition = cursor ? Number.parseInt(cursor, 10) : 0;
      const filtered = accountEntries.filter((entry) => entry.feedPosition > cursorPosition);
      const page = filtered.slice(0, limit);
      const lastPosition = page.length > 0 ? page[page.length - 1].feedPosition : cursorPosition;

      return {
        entries: page,
        nextCursor: String(lastPosition),
        hasMore: filtered.length > page.length,
      };
    });
  }
}

export function createFileBackedStores(storageDir: string): {
  envelopeStore: EnvelopeStore;
  feedStore: SyncFeedStore;
  snapshotPath: string;
} {
  const coordinator = new FileStorageCoordinator(storageDir);
  return {
    envelopeStore: new FileEnvelopeStore(coordinator),
    feedStore: new FileSyncFeedStore(coordinator),
    snapshotPath: coordinator.snapshotPath,
  };
}
