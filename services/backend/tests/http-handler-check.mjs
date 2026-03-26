import { handlePull, handlePush, InMemoryEnvelopeStore, InMemorySyncFeedStore, SyncService } from "../dist/index.js";

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function makeEnvelope({
  id,
  syncVersion = 0,
  title = "Morning walk",
  durationSeconds = 2700,
} = {}) {
  return {
    segment: {
      id,
      startTime: "2026-03-26T08:00:00Z",
      endTime: "2026-03-26T08:45:00Z",
      lifecycleState: "settled",
      originType: "system",
      primaryDeviceHint: "iPhone",
      title,
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
      durationSeconds,
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

const service = new SyncService(new InMemoryEnvelopeStore(), new InMemorySyncFeedStore());

const missingAccountResult = await handlePush(service, {
  deviceID: "iphone-1",
  changes: []
});
assert(missingAccountResult.statusCode === 400, "missing accountID should return 400");

const invalidEnvelopeResult = await handlePush(service, {
  deviceID: "iphone-1",
  accountID: "account-123",
  changes: [
    {
      baseSyncVersion: 0,
      segmentEnvelope: makeEnvelope({
        id: "segment-1",
        durationSeconds: 900
      })
    }
  ]
});
assert(invalidEnvelopeResult.statusCode === 422, "invalid envelope should return 422");
assert(invalidEnvelopeResult.body.field === "summary.durationSeconds", "invalid envelope should point to summary.durationSeconds");

const acceptedPush = await handlePush(service, {
  deviceID: "iphone-1",
  accountID: "account-123",
  changes: [
    {
      baseSyncVersion: 0,
      segmentEnvelope: makeEnvelope({
        id: "segment-1"
      })
    }
  ]
});
assert(acceptedPush.statusCode === 200, "valid push should return 200");
assert(acceptedPush.body.accepted.length === 1, "valid push should accept one change");

const conflictPush = await handlePush(service, {
  deviceID: "iphone-1",
  accountID: "account-123",
  changes: [
    {
      baseSyncVersion: 0,
      segmentEnvelope: makeEnvelope({
        id: "segment-1",
        title: "Stale title"
      })
    }
  ]
});
assert(conflictPush.statusCode === 200, "conflicting push should still return 200");
assert(conflictPush.body.conflicts.length === 1, "conflicting push should return one conflict");
assert(conflictPush.body.conflicts[0].reason === "versionMismatch", "conflicting push should report versionMismatch");

const missingPullAccount = await handlePull(service, {
  deviceID: "iphone-1"
});
assert(missingPullAccount.statusCode === 400, "missing pull accountID should return 400");

const pullResult = await handlePull(service, {
  deviceID: "iphone-1",
  accountID: "account-123"
});
assert(pullResult.statusCode === 200, "valid pull should return 200");
assert(pullResult.body.changes.length === 1, "valid pull should return one change");
assert(pullResult.body.nextCursor === "1", "valid pull should advance cursor");

console.log("http-handler-check: ok");
