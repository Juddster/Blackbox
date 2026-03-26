import { mkdtemp, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { createConfiguredStores, SyncService } from "../dist/index.js";

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function makeEnvelope(id, syncVersion = 0) {
  return {
    segment: {
      id,
      startTime: "2026-03-26T08:00:00Z",
      endTime: "2026-03-26T08:45:00Z",
      lifecycleState: "settled",
      originType: "system",
      primaryDeviceHint: "iPhone",
      title: "Persistent walk",
      createdAt: "2026-03-26T08:46:00Z",
      updatedAt: "2026-03-26T09:00:00Z"
    },
    interpretation: {
      id: `${id}-interpretation`,
      segmentID: id,
      visibleClass: "walking",
      userSelectedClass: null,
      confidence: 0.82,
      ambiguityState: "clear",
      needsReview: false,
      interpretationOrigin: "system",
      updatedAt: "2026-03-26T09:00:00Z"
    },
    summary: {
      id: `${id}-summary`,
      segmentID: id,
      durationSeconds: 2700,
      distanceMeters: 3200,
      elevationGainMeters: 30,
      averageSpeedMetersPerSecond: 1.18,
      maxSpeedMetersPerSecond: 1.9,
      pauseCount: 0,
      updatedAt: "2026-03-26T09:00:00Z"
    },
    sync: {
      lastModifiedByDeviceID: "iphone-1",
      lastModifiedAt: "2026-03-26T09:00:00Z",
      syncVersion,
      isDeleted: false
    }
  };
}

const storageDir = await mkdtemp(path.join(os.tmpdir(), "blackbox-backend-file-store-"));

try {
  const firstStores = createConfiguredStores(storageDir);
  assert(firstStores.mode === "file", "configured stores should select file mode");

  const firstService = new SyncService(firstStores.envelopeStore, firstStores.feedStore);
  const firstPush = await firstService.push({
    deviceID: "iphone-1",
    accountID: "account-123",
    changes: [
      {
        baseSyncVersion: 0,
        segmentEnvelope: makeEnvelope("segment-1")
      }
    ]
  });

  assert("accepted" in firstPush, "first push should succeed");
  assert(firstPush.accepted.length === 1, "first push should accept one change");

  const secondStores = createConfiguredStores(storageDir);
  const secondService = new SyncService(secondStores.envelopeStore, secondStores.feedStore);
  const pull = await secondService.pull({
    deviceID: "iphone-2",
    accountID: "account-123"
  });

  assert(pull.changes.length === 1, "file-backed store should retain pushed change across service instances");
  assert(pull.nextCursor === "1", "file-backed store should retain feed cursor progression");
  assert(secondStores.snapshotPath?.endsWith("sync-state.json") === true, "file-backed store should expose snapshot path");

  console.log("file-storage-check: ok");
} finally {
  await rm(storageDir, { recursive: true, force: true });
}
