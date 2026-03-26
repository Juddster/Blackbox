import { EnvelopeStore, SyncFeedStore } from "./interfaces.js";
import { InMemoryEnvelopeStore, InMemorySyncFeedStore } from "./memory.js";
import { createFileBackedStores } from "./file.js";

export interface ConfiguredStores {
  envelopeStore: EnvelopeStore;
  feedStore: SyncFeedStore;
  mode: "memory" | "file";
  snapshotPath?: string;
}

export function createConfiguredStores(
  fileStorageDir = process.env.BLACKBOX_FILE_STORAGE_DIR
): ConfiguredStores {
  if (fileStorageDir && fileStorageDir.trim().length > 0) {
    const configured = createFileBackedStores(fileStorageDir);
    return {
      ...configured,
      mode: "file",
    };
  }

  return {
    envelopeStore: new InMemoryEnvelopeStore(),
    feedStore: new InMemorySyncFeedStore(),
    mode: "memory",
  };
}
