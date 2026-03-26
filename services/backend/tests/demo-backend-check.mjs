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

const malformedRequest = backend.push({
  deviceID: "iphone-1",
  changes: []
});

assert(malformedRequest.statusCode === 400, "missing accountID should return 400");

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

const mixedBatch = backend.push({
  deviceID: "iphone-1",
  accountID: "account-123",
  changes: [
    {
      baseSyncVersion: 0,
      segmentEnvelope: makeEnvelope({ id: "segment-3", title: "Fresh segment" })
    },
    {
      baseSyncVersion: 0,
      segmentEnvelope: makeEnvelope({ id: "segment-1", title: "Still stale" })
    }
  ]
});

assert(mixedBatch.statusCode === 200, "mixed batch should return 200");
assert(mixedBatch.body.accepted.length === 1, "mixed batch should accept one change");
assert(mixedBatch.body.conflicts.length === 1, "mixed batch should also return one conflict");
assert(mixedBatch.body.accepted[0].segmentID === "segment-3", "mixed batch should accept the fresh segment");

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
assert(pull.body.changes.length === 2, "pull should return the accepted segments");
assert(pull.body.changes[0].segmentEnvelope.segment.id === "segment-1", "pull should preserve the first accepted segment");
assert(pull.body.changes[1].segmentEnvelope.segment.id === "segment-3", "pull should preserve append order for later accepted segments");
assert(pull.body.changes[0].segmentEnvelope.sync.syncVersion === 1, "pulled envelope should include server syncVersion");

const secondPush = backend.push({
  deviceID: "iphone-1",
  accountID: "account-123",
  changes: [
    {
      baseSyncVersion: 0,
      segmentEnvelope: makeEnvelope({ id: "segment-2", title: "Second segment" })
    }
  ]
});

assert(secondPush.statusCode === 200, "second push should return 200");
assert(secondPush.body.accepted.length === 1, "second push should accept one change");

const incrementalPull = backend.pull({
  deviceID: "iphone-1",
  accountID: "account-123",
  cursor: pull.body.nextCursor
});

assert(incrementalPull.statusCode === 200, "incremental pull should return 200");
assert(incrementalPull.body.changes.length === 1, "incremental pull should return only the later segment");
assert(incrementalPull.body.changes[0].segmentEnvelope.segment.id === "segment-2", "incremental pull should preserve append order");

const tombstonePush = backend.push({
  deviceID: "iphone-1",
  accountID: "account-123",
  changes: [
    {
      baseSyncVersion: 1,
      segmentEnvelope: {
        ...makeEnvelope({ id: "segment-2", title: "Second segment" }),
        segment: {
          ...makeEnvelope({ id: "segment-2", title: "Second segment" }).segment,
          lifecycleState: "deleted"
        },
        sync: {
          ...makeEnvelope({ id: "segment-2", title: "Second segment" }).sync,
          isDeleted: true
        }
      }
    }
  ]
});

assert(tombstonePush.statusCode === 200, "tombstone push should return 200");
assert(tombstonePush.body.accepted.length === 1, "tombstone push should be accepted");
assert(tombstonePush.body.accepted[0].syncVersion === 2, "tombstone push should advance syncVersion");

const tombstonePull = backend.pull({
  deviceID: "iphone-1",
  accountID: "account-123",
  cursor: incrementalPull.body.nextCursor
});

assert(tombstonePull.statusCode === 200, "tombstone pull should return 200");
assert(tombstonePull.body.changes.length === 1, "tombstone pull should return the deleted segment");
assert(tombstonePull.body.changes[0].segmentEnvelope.sync.isDeleted === true, "tombstone pull should include deleted sync state");

const deletedOnServerConflict = backend.push({
  deviceID: "iphone-1",
  accountID: "account-123",
  changes: [
    {
      baseSyncVersion: 1,
      segmentEnvelope: makeEnvelope({ id: "segment-2", title: "Stale client edit" })
    }
  ]
});

assert(deletedOnServerConflict.statusCode === 200, "deleted-on-server conflict should return 200");
assert(deletedOnServerConflict.body.conflicts.length === 1, "deleted-on-server conflict should return one conflict");
assert(deletedOnServerConflict.body.conflicts[0].reason === "deletedOnServer", "deleted segment conflict should use deletedOnServer reason");

const restoreAttempt = backend.push({
  deviceID: "iphone-1",
  accountID: "account-123",
  changes: [
    {
      baseSyncVersion: 2,
      segmentEnvelope: makeEnvelope({ id: "segment-2", title: "Attempted restore" })
    }
  ]
});

assert(restoreAttempt.statusCode === 200, "restore attempt should still return 200");
assert(restoreAttempt.body.conflicts.length === 1, "restore attempt should be blocked as a conflict");
assert(restoreAttempt.body.conflicts[0].reason === "deletedOnServer", "restore attempt should still report deletedOnServer");

console.log("demo-backend-check: ok");
