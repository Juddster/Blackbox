# Validation Rules

This document defines the first backend-side validation rules for the initial sync slice.

It is intentionally narrow and only covers the first required sync unit:
- `SegmentEnvelope`

## Goal

Reject malformed or contradictory sync payloads early and predictably.

The backend should be strict enough to keep durable semantic history coherent, but not so strict that harmless optional omissions break ordinary client progress.

## Validation Scope

These rules apply to:
- `POST /v1/sync/push`
- incoming `SegmentEnvelope` payloads

## Envelope-Level Rules

### Required Top-Level Parts

The payload must include:
- `segment`
- `sync`

The payload may include:
- `interpretation`
- `summary`

### Identifier Consistency

- `segment.id` is required
- if `interpretation` is present, `interpretation.segmentID` must equal `segment.id`
- if `summary` is present, `summary.segmentID` must equal `segment.id`

### Timestamp Presence

The following must be present:
- `segment.startTime`
- `segment.endTime`
- `segment.createdAt`
- `segment.updatedAt`
- `sync.lastModifiedAt`

### Segment Time Ordering

- `segment.endTime` must not be earlier than `segment.startTime`

### Lifecycle / Tombstone Coherence

- if `sync.isDeleted == true`, the server should treat the envelope as a tombstone/update for deletion
- a tombstoned segment must still carry enough identity and sync metadata to reconcile offline devices

## Segment Rules

### Required Segment Fields

- `id`
- `startTime`
- `endTime`
- `lifecycleState`
- `originType`
- `primaryDeviceHint`
- `createdAt`
- `updatedAt`

### Title

- `title` may be empty or omitted only if the contract later explicitly permits that
- for the current contract shape, treat `title` as required

### Enum Validation

Reject unknown values for:
- `lifecycleState`
- `originType`
- `primaryDeviceHint`

## Interpretation Rules

If `interpretation` is present:

- `visibleClass` must be a valid broad activity enum
- `confidence` must be within an acceptable numeric range
- `ambiguityState` must be valid
- `interpretationOrigin` must be valid

### userSelectedClass

- `userSelectedClass` is intentionally not limited to the broad visible-class enum
- treat it as a user-authored narrower label string
- reject only if it violates transport/shape constraints, not because it is not a known broad enum

## Summary Rules

If `summary` is present:

- `durationSeconds` must be non-negative
- `durationSeconds` should materially match the segment time range
- `pauseCount` must be non-negative
- `distanceMeters`, `elevationGainMeters`, `averageSpeedMetersPerSecond`, and `maxSpeedMetersPerSecond` must not be negative if present

### Partial Summary Acceptance

The backend should allow partial/early summaries if the contract says summary is optional.

That means:
- missing summary is acceptable
- present but incomplete summary should only be rejected if required fields are missing from the accepted contract shape

## Sync Metadata Rules

Required:
- `lastModifiedByDeviceID`
- `lastModifiedAt`
- `syncVersion`
- `isDeleted`

### syncVersion Rules

- `syncVersion` from the client is used for conflict detection, not as something the client gets to redefine authoritatively
- server-side monotonic versioning remains authoritative

## Conflict vs Validation

Important distinction:

- malformed or contradictory payloads should fail validation
- version mismatches should produce conflicts, not validation errors

Examples:

Validation error:
- `interpretation.segmentID != segment.id`

Conflict:
- `baseSyncVersion` does not match server state

## Recommended Error Shape

Validation responses should use the shared `ValidationError` pattern from:
- `Docs/DevCoordination/api-shapes.md`

At minimum include:
- `code`
- `message`
- `field` when the problem is field-specific

## First-Slice Restraint

The backend should not add validation complexity for deferred concepts in the first slice.

That means no first-slice validation is needed yet for:
- collections
- exports
- first-class review envelopes
- support evidence uploads
- live share payloads
