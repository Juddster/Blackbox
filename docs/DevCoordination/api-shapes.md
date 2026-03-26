# Blackbox API Shapes

This document exists to give backend and Apple app work a stable shared payload vocabulary.

## Conventions

- All timestamps are ISO 8601 UTC strings.
- All durable identifiers are UUID strings.
- Enum values are sent as strings.
- Omitted optional values and explicit `null` should be treated consistently by the backend.

## Enums

### ActivityClass

- `stationary`
- `walking`
- `running`
- `cycling`
- `hiking`
- `vehicle`
- `flight`
- `waterActivity`
- `unknown`

### SegmentLifecycleState

- `active`
- `unsettled`
- `settled`
- `deleted`

### SegmentOriginType

- `system`
- `userCreated`
- `merged`
- `splitResult`

### ObservationSourceDevice

- `iPhone`
- `watch`

### InterpretationOrigin

- `system`
- `user`
- `mixed`

### AmbiguityState

- `clear`
- `mixed`
- `uncertain`

## Records

### Segment

```json
{
  "id": "uuid",
  "startTime": "ISO8601",
  "endTime": "ISO8601",
  "lifecycleState": "settled",
  "originType": "system",
  "primaryDeviceHint": "iPhone",
  "title": "Morning walk",
  "createdAt": "ISO8601",
  "updatedAt": "ISO8601"
}
```

### SegmentInterpretation

```json
{
  "id": "uuid",
  "segmentID": "uuid",
  "visibleClass": "walking",
  "userSelectedClass": "publicTransportation",
  "confidence": 0.92,
  "ambiguityState": "clear",
  "needsReview": false,
  "interpretationOrigin": "system",
  "updatedAt": "ISO8601"
}
```

Notes:
- `visibleClass` is the constrained broad class used by the system and the main sync contract.
- `userSelectedClass` is a user-authored narrower label and is intentionally a free-form contract string, not limited to the broad visible-class enum.
- Examples of `userSelectedClass` may include:
  - `publicTransportation`
  - `bus`
  - `train`
  - `motorcycle`
  - `stairClimbing`
  - other future user-facing labels

### SegmentSummary

```json
{
  "id": "uuid",
  "segmentID": "uuid",
  "durationSeconds": 2400,
  "distanceMeters": 3100,
  "elevationGainMeters": 42,
  "averageSpeedMetersPerSecond": 1.29,
  "maxSpeedMetersPerSecond": 1.8,
  "pauseCount": 0,
  "updatedAt": "ISO8601"
}
```

### SyncMetadata

```json
{
  "lastModifiedByDeviceID": "device-123",
  "lastModifiedAt": "ISO8601",
  "syncVersion": 4,
  "isDeleted": false
}
```

## Error Payloads

### ConflictError

```json
{
  "code": "versionMismatch",
  "segmentID": "uuid",
  "message": "Client version does not match server version",
  "serverEnvelope": {}
}
```

### ValidationError

```json
{
  "code": "invalidPayload",
  "message": "visibleClass is invalid",
  "field": "interpretation.visibleClass"
}
```
