import { SyncService } from "../domain/sync-service.js";
import { PushRequest } from "../domain/types.js";
import { InMemoryEnvelopeStore, InMemorySyncFeedStore } from "../storage/memory.js";

export async function runSmokeExample() {
  const envelopes = new InMemoryEnvelopeStore();
  const feed = new InMemorySyncFeedStore();
  const service = new SyncService(envelopes, feed);

  const pushRequest: PushRequest = {
    deviceID: "iphone-1",
    accountID: "account-123",
    changes: [
      {
        baseSyncVersion: 0,
        segmentEnvelope: {
          segment: {
            id: "f6c0a0ee-1111-2222-3333-444444444444",
            startTime: "2026-03-26T08:00:00Z",
            endTime: "2026-03-26T08:45:00Z",
            lifecycleState: "settled",
            originType: "system",
            primaryDeviceHint: "iPhone",
            title: "Morning walk",
            createdAt: "2026-03-26T08:46:00Z",
            updatedAt: "2026-03-26T09:00:00Z",
          },
          interpretation: {
            id: "8ac1b7fd-1111-2222-3333-444444444444",
            segmentID: "f6c0a0ee-1111-2222-3333-444444444444",
            visibleClass: "walking",
            userSelectedClass: null,
            confidence: 0.82,
            ambiguityState: "clear",
            needsReview: false,
            interpretationOrigin: "system",
            updatedAt: "2026-03-26T09:00:00Z",
          },
          summary: {
            id: "9b7db3a0-1111-2222-3333-444444444444",
            segmentID: "f6c0a0ee-1111-2222-3333-444444444444",
            durationSeconds: 2700,
            distanceMeters: 3200,
            elevationGainMeters: 30,
            averageSpeedMetersPerSecond: 1.18,
            maxSpeedMetersPerSecond: 1.9,
            pauseCount: 0,
            updatedAt: "2026-03-26T09:00:00Z",
          },
          sync: {
            lastModifiedByDeviceID: "iphone-1",
            lastModifiedAt: "2026-03-26T09:00:00Z",
            syncVersion: 0,
            isDeleted: false,
          },
        },
      },
    ],
  };

  const pushResult = await service.push(pushRequest);
  const pullResult = await service.pull({
    accountID: "account-123",
    deviceID: "iphone-1",
  });

  return {
    pushResult,
    pullResult,
  };
}
