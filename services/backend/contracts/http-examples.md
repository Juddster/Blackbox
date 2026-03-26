# HTTP Sync Examples

This file gives compact end-to-end HTTP examples for the first backend sync slice.

It is meant to complement:
- the shared contract docs
- the backend semantics docs
- the conflict-response examples

## 1. Push Request Example

`POST /v1/sync/push`

```json
{
  "deviceID": "iphone-1",
  "accountID": "account-123",
  "changes": [
    {
      "segmentEnvelope": {
        "segment": {
          "id": "f6c0a0ee-1111-2222-3333-444444444444",
          "startTime": "2026-03-26T08:00:00Z",
          "endTime": "2026-03-26T08:45:00Z",
          "lifecycleState": "settled",
          "originType": "system",
          "primaryDeviceHint": "iPhone",
          "title": "Morning walk",
          "createdAt": "2026-03-26T08:46:00Z",
          "updatedAt": "2026-03-26T09:00:00Z"
        },
        "interpretation": {
          "id": "8ac1b7fd-1111-2222-3333-444444444444",
          "segmentID": "f6c0a0ee-1111-2222-3333-444444444444",
          "visibleClass": "walking",
          "userSelectedClass": null,
          "confidence": 0.82,
          "ambiguityState": "clear",
          "needsReview": false,
          "interpretationOrigin": "system",
          "updatedAt": "2026-03-26T09:00:00Z"
        },
        "summary": {
          "id": "9b7db3a0-1111-2222-3333-444444444444",
          "segmentID": "f6c0a0ee-1111-2222-3333-444444444444",
          "durationSeconds": 2700,
          "distanceMeters": 3200,
          "elevationGainMeters": 30,
          "averageSpeedMetersPerSecond": 1.18,
          "maxSpeedMetersPerSecond": 1.9,
          "pauseCount": 0,
          "updatedAt": "2026-03-26T09:00:00Z"
        },
        "sync": {
          "lastModifiedByDeviceID": "iphone-1",
          "lastModifiedAt": "2026-03-26T09:00:00Z",
          "syncVersion": 3,
          "isDeleted": false
        }
      },
      "baseSyncVersion": 3
    }
  ]
}
```

## 2. Push Accepted Response Example

```json
{
  "accepted": [
    {
      "segmentID": "f6c0a0ee-1111-2222-3333-444444444444",
      "syncVersion": 4,
      "updatedAt": "2026-03-26T09:12:00Z"
    }
  ],
  "conflicts": []
}
```

## 3. Push Conflict Response Example

```json
{
  "accepted": [],
  "conflicts": [
    {
      "segmentID": "f6c0a0ee-1111-2222-3333-444444444444",
      "reason": "versionMismatch",
      "serverEnvelope": {
        "segment": {
          "id": "f6c0a0ee-1111-2222-3333-444444444444",
          "startTime": "2026-03-26T08:00:00Z",
          "endTime": "2026-03-26T08:45:00Z",
          "lifecycleState": "settled",
          "originType": "system",
          "primaryDeviceHint": "iPhone",
          "title": "Morning walk",
          "createdAt": "2026-03-26T08:46:00Z",
          "updatedAt": "2026-03-26T09:15:00Z"
        },
        "interpretation": {
          "id": "8ac1b7fd-1111-2222-3333-444444444444",
          "segmentID": "f6c0a0ee-1111-2222-3333-444444444444",
          "visibleClass": "walking",
          "userSelectedClass": null,
          "confidence": 0.84,
          "ambiguityState": "clear",
          "needsReview": false,
          "interpretationOrigin": "system",
          "updatedAt": "2026-03-26T09:15:00Z"
        },
        "summary": {
          "id": "9b7db3a0-1111-2222-3333-444444444444",
          "segmentID": "f6c0a0ee-1111-2222-3333-444444444444",
          "durationSeconds": 2700,
          "distanceMeters": 3225,
          "elevationGainMeters": 30,
          "averageSpeedMetersPerSecond": 1.19,
          "maxSpeedMetersPerSecond": 1.9,
          "pauseCount": 0,
          "updatedAt": "2026-03-26T09:15:00Z"
        },
        "sync": {
          "lastModifiedByDeviceID": "watch-1",
          "lastModifiedAt": "2026-03-26T09:15:00Z",
          "syncVersion": 4,
          "isDeleted": false
        }
      }
    }
  ]
}
```

## 4. Pull Request Example

`POST /v1/sync/pull`

```json
{
  "deviceID": "iphone-1",
  "accountID": "account-123",
  "cursor": "cursor-00041"
}
```

## 5. Pull Response Example

```json
{
  "changes": [
    {
      "segmentEnvelope": {
        "segment": {
          "id": "f6c0a0ee-1111-2222-3333-444444444444",
          "startTime": "2026-03-26T08:00:00Z",
          "endTime": "2026-03-26T08:45:00Z",
          "lifecycleState": "settled",
          "originType": "system",
          "primaryDeviceHint": "iPhone",
          "title": "Morning walk",
          "createdAt": "2026-03-26T08:46:00Z",
          "updatedAt": "2026-03-26T09:15:00Z"
        },
        "interpretation": {
          "id": "8ac1b7fd-1111-2222-3333-444444444444",
          "segmentID": "f6c0a0ee-1111-2222-3333-444444444444",
          "visibleClass": "walking",
          "userSelectedClass": null,
          "confidence": 0.84,
          "ambiguityState": "clear",
          "needsReview": false,
          "interpretationOrigin": "system",
          "updatedAt": "2026-03-26T09:15:00Z"
        },
        "summary": {
          "id": "9b7db3a0-1111-2222-3333-444444444444",
          "segmentID": "f6c0a0ee-1111-2222-3333-444444444444",
          "durationSeconds": 2700,
          "distanceMeters": 3225,
          "elevationGainMeters": 30,
          "averageSpeedMetersPerSecond": 1.19,
          "maxSpeedMetersPerSecond": 1.9,
          "pauseCount": 0,
          "updatedAt": "2026-03-26T09:15:00Z"
        },
        "sync": {
          "lastModifiedByDeviceID": "watch-1",
          "lastModifiedAt": "2026-03-26T09:15:00Z",
          "syncVersion": 4,
          "isDeleted": false
        }
      }
    }
  ],
  "nextCursor": "cursor-00042",
  "hasMore": false
}
```
