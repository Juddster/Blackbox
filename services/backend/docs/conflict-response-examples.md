# Conflict Response Examples

This document gives concrete examples of how the backend should respond to common first-slice sync conflicts.

It is scoped only to the initial segment-envelope sync model.

## Goal

Make conflict behavior concrete enough that:
- Apple client work
- backend work
- and shared contract work

can stay aligned without inventing different conflict semantics independently.

## First-Slice Reminder

These examples apply to:
- `SegmentEnvelope`

They do not yet cover:
- collections
- exports
- first-class review envelopes

## 1. Version Mismatch Conflict

### Situation

- client pushes `baseSyncVersion = 3`
- server currently has `syncVersion = 4`

### Response

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
          "syncVersion": 4,
          "isDeleted": false
        }
      }
    }
  ]
}
```

## 2. Tombstone Conflict

### Situation

- client edits a segment that the server now stores as deleted

### Response

```json
{
  "accepted": [],
  "conflicts": [
    {
      "segmentID": "f6c0a0ee-1111-2222-3333-444444444444",
      "reason": "deletedOnServer",
      "serverEnvelope": {
        "segment": {
          "id": "f6c0a0ee-1111-2222-3333-444444444444",
          "startTime": "2026-03-26T08:00:00Z",
          "endTime": "2026-03-26T08:45:00Z",
          "lifecycleState": "deleted",
          "originType": "system",
          "primaryDeviceHint": "iPhone",
          "title": "Morning walk",
          "createdAt": "2026-03-26T08:46:00Z",
          "updatedAt": "2026-03-26T10:10:00Z"
        },
        "interpretation": null,
        "summary": null,
        "sync": {
          "lastModifiedByDeviceID": "iphone-2",
          "lastModifiedAt": "2026-03-26T10:10:00Z",
          "syncVersion": 7,
          "isDeleted": true
        }
      }
    }
  ]
}
```

## 3. Validation Error

### Situation

- client sends a malformed segment envelope where `interpretation.segmentID` does not match `segment.id`

### Response

```json
{
  "code": "invalidPayload",
  "message": "interpretation.segmentID must match segment.id",
  "field": "interpretation.segmentID"
}
```

## 4. Accepted Push

### Situation

- client sends a valid update with matching `baseSyncVersion`

### Response

```json
{
  "accepted": [
    {
      "segmentID": "f6c0a0ee-1111-2222-3333-444444444444",
      "syncVersion": 5,
      "updatedAt": "2026-03-26T09:12:00Z"
    }
  ],
  "conflicts": []
}
```

## 5. User Beats System Example

### Situation

- local client has a user-selected narrower label
- server has only system-authored interpretation changes

### Expected Resolution Direction

- user-authored interpretation wins
- server envelope is still returned on conflict if versions differ
- client may deterministically resolve by preserving user-selected interpretation and resubmitting

## Practical Notes

- conflicts are not validation failures
- validation failures are not version conflicts
- tombstones must be explicit
- first-slice conflict behavior should stay envelope-level and predictable
