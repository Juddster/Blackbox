import { createDemoBackend } from "../demo-lib.mjs";

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function makeEnvelope({
  id,
  syncVersion = 0,
  title = "Morning walk",
  userSelectedClass = null,
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
      userSelectedClass,
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

const backend = createDemoBackend();

const firstPush = backend.push({
  deviceID: "iphone-1",
  accountID: "account-123",
  changes: [
    {
      baseSyncVersion: 0,
      segmentEnvelope: makeEnvelope({ id: "segment-1" })
    }
  ]
});

assert(firstPush.statusCode === 200, "first push should return 200");
assert(firstPush.body.accepted.length === 1, "first push should accept one change");
assert(firstPush.body.accepted[0].syncVersion === 1, "first push should assign syncVersion 1");

const conflictPush = backend.push({
  deviceID: "iphone-1",
  accountID: "account-123",
  changes: [
    {
      baseSyncVersion: 0,
      segmentEnvelope: makeEnvelope({ id: "segment-1", title: "Stale edit" })
    }
  ]
});

assert(conflictPush.statusCode === 200, "conflict push should still return 200");
assert(conflictPush.body.conflicts.length === 1, "conflict push should report one conflict");
assert(conflictPush.body.conflicts[0].reason === "versionMismatch", "conflict reason should be versionMismatch");

const validationFailure = backend.push({
  deviceID: "iphone-1",
  accountID: "account-123",
  changes: [
    {
      baseSyncVersion: 0,
      segmentEnvelope: {
        ...makeEnvelope({ id: "segment-2" }),
        interpretation: {
          ...makeEnvelope({ id: "segment-2" }).interpretation,
          segmentID: "wrong-id"
        }
      }
    }
  ]
});

assert(validationFailure.statusCode === 422, "validation failure should return 422");

const pull = backend.pull({
  deviceID: "iphone-1",
  accountID: "account-123"
});

assert(pull.statusCode === 200, "pull should return 200");
assert(pull.body.changes.length === 1, "pull should return the accepted segment");
assert(pull.body.changes[0].segmentEnvelope.sync.syncVersion === 1, "pulled envelope should include server syncVersion");

console.log("demo-backend-check: ok");
