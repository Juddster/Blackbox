# Blackbox Sync Contract

This document defines the first client/server contract between the Apple app and the backend.

Its goal is to let iOS and backend work proceed in parallel without blocking on informal coordination.

Machine-readable counterparts:
- `packages/shared/contracts/segment-envelope.schema.json`
- `packages/shared/contracts/sync-push.schema.json`
- `packages/shared/contracts/sync-pull.schema.json`
- `packages/shared/contracts/examples/`

## Scope

This contract covers the first v1 durable semantic sync slice for:
- segments
- current interpretation state
- current summary state
- compact review markers only if we later promote them beyond segment-folded state

It explicitly does not cover:
- dense raw observation upload by default
- collections as first-class sync units
- export metadata as first-class sync units
- live sharing
- web UI requirements
- complex multi-user sharing models

For clarity:
- the initial mandatory sync contract is `SegmentEnvelope`
- collections, exports, and first-class review sync are later extensions unless explicitly promoted

## Sync Principles

- The app is local-first.
- Cloud provides durability and multi-device continuity.
- The phone must remain operational when offline.
- The server is not part of the real-time capture loop.
- Sync should be current-state oriented for v1, not event-sourced.

## Unit Of Sync

The primary sync unit is a `SegmentEnvelope`.

A `SegmentEnvelope` contains:
- segment record
- current interpretation record
- current summary record
- sync metadata

This matches the product direction that the semantic history is the durable thing that syncs.

Optional later sync units may include:
- `CollectionEnvelope`
- `ExportEnvelope`
- `ReviewItemEnvelope` or folded review state

## Canonical Identifiers

Rules:
- The client generates UUIDs for durable records.
- UUIDs are stable across offline edits and later sync.
- The server must not replace client UUIDs with server IDs for synced semantic records.
- Server-side storage may have internal primary keys, but UUID remains the public durable identifier.

## Ownership Model

For v1:
- The current effective segment state is the only synced semantic truth.
- Split and merge operations are represented as replacement current state, not rich version history.
- User edits are authoritative over automatic interpretation.
- If a segment is deleted, sync should propagate a tombstone rather than silently disappearing it.

## Core Records

## SegmentEnvelope

```json
{
  "segment": {
    "id": "uuid",
    "startTime": "ISO8601",
    "endTime": "ISO8601",
    "lifecycleState": "active | unsettled | settled | deleted",
    "originType": "system | userCreated | merged | splitResult",
    "primaryDeviceHint": "iPhone | watch",
    "title": "string",
    "createdAt": "ISO8601",
    "updatedAt": "ISO8601"
  },
  "interpretation": {
    "id": "uuid",
    "segmentID": "uuid",
    "visibleClass": "stationary | walking | running | cycling | hiking | vehicle | flight | waterActivity | unknown",
    "userSelectedClass": "free-form narrower label or null",
    "confidence": 0.0,
    "ambiguityState": "clear | mixed | uncertain",
    "needsReview": true,
    "interpretationOrigin": "system | user | mixed",
    "updatedAt": "ISO8601"
  },
  "summary": {
    "id": "uuid",
    "segmentID": "uuid",
    "durationSeconds": 0,
    "distanceMeters": 0.0,
    "elevationGainMeters": 0.0,
    "averageSpeedMetersPerSecond": 0.0,
    "maxSpeedMetersPerSecond": 0.0,
    "pauseCount": 0,
    "updatedAt": "ISO8601"
  },
  "sync": {
    "lastModifiedByDeviceID": "string",
    "lastModifiedAt": "ISO8601",
    "syncVersion": 1,
    "isDeleted": false
  }
}
```

Notes:
- `summary` may be null for incomplete or early records.
- `interpretation.userSelectedClass` being non-null means user intent must win.
- `interpretation.userSelectedClass` is intentionally not restricted to the broad visible-class enum.
- `syncVersion` is a monotonic server-issued version for conflict detection.

## Conflict Model

Use a simple v1 conflict model.

Rules:
- The server stores a monotonic `syncVersion` per segment envelope.
- The client sends its last known `syncVersion` when pushing changes.
- If versions match, the server accepts and increments.
- If versions differ, the server returns a conflict payload with server state.

Conflict policy:
- Default policy is last-writer-wins at the envelope level for system-authored changes.
- User-authored interpretation must win over system-authored interpretation when resolving mixed conflicts.
- Deletion must require explicit tombstone handling, not silent overwrite.

## API Shape

Initial minimal endpoints:

- `POST /v1/sync/push`
- `POST /v1/sync/pull`

### Push Request

```json
{
  "deviceID": "string",
  "accountID": "string",
  "changes": [
    {
      "segmentEnvelope": {},
      "baseSyncVersion": 3
    }
  ]
}
```

### Push Response

```json
{
  "accepted": [
    {
      "segmentID": "uuid",
      "syncVersion": 4,
      "updatedAt": "ISO8601"
    }
  ],
  "conflicts": [
    {
      "segmentID": "uuid",
      "reason": "versionMismatch",
      "serverEnvelope": {}
    }
  ]
}
```

### Pull Request

```json
{
  "deviceID": "string",
  "accountID": "string",
  "cursor": "opaque-string"
}
```

### Pull Response

```json
{
  "changes": [
    {
      "segmentEnvelope": {}
    }
  ],
  "nextCursor": "opaque-string",
  "hasMore": false
}
```

## Optional Extension Envelopes

These are not required for the minimal first sync slice, but defining them here reduces future ambiguity.

### CollectionEnvelope

Possible shape:

```json
{
  "collection": {
    "id": "uuid",
    "title": "string",
    "createdAt": "ISO8601",
    "updatedAt": "ISO8601"
  },
  "memberships": [
    {
      "segmentID": "uuid",
      "sortOrder": 0,
      "addedAt": "ISO8601"
    }
  ],
  "sync": {
    "lastModifiedByDeviceID": "string",
    "lastModifiedAt": "ISO8601",
    "syncVersion": 1,
    "isDeleted": false
  }
}
```

### ExportEnvelope

Possible shape:

```json
{
  "export": {
    "id": "uuid",
    "sourceType": "segment | collection",
    "sourceID": "uuid",
    "exportType": "string",
    "title": "string",
    "createdAt": "ISO8601"
  },
  "sync": {
    "lastModifiedByDeviceID": "string",
    "lastModifiedAt": "ISO8601",
    "syncVersion": 1,
    "isDeleted": false
  }
}
```

### Review Sync Shape

Two acceptable directions remain open:
- sync `ReviewItem` as its own first-class envelope
- fold review state into `SegmentEnvelope` and keep only compact review markers server-side

Current recommendation:
- start with compact review state folded into `SegmentEnvelope` unless the Apple app or backend has a concrete need for first-class review records

## Cursor Model

- Pull should be incremental.
- The server owns the cursor format.
- The client treats the cursor as opaque.
- Pull ordering must be stable enough that replaying from the same cursor does not miss changes.

## Deletion Model

- Segment deletion syncs as a tombstone.
- Tombstones must include `id`, `updatedAt`, `syncVersion`, and `isDeleted`.
- The server should retain tombstones long enough for offline devices to observe deletion.

## What Does Not Sync By Default

These remain local by default:
- dense observation streams
- transient diagnostics
- temporary capture buffers
- most support evidence after settlement

These may sync later selectively:
- retained support evidence for unsettled segments
- in-progress activity snapshots
- review sub-interval metadata

## Responsibilities Split

Apple app owns:
- local semantic persistence
- offline mutation
- push/pull execution
- conflict presentation when automatic resolution is unsafe
- reconciliation of synced state into the Apple local persistence layer

Backend owns:
- account scoping
- durable storage
- monotonic sync versioning
- pull cursors
- conflict responses
- tombstone retention

## Open Questions

- Whether collections join the first sync slice or the second one.
- Whether review items should sync as first-class records or fold into segment state.
- Whether exports in sync carry metadata only or also payload references.
- Whether active and unsettled segments need higher-priority push semantics.

## Current Recommendation

If we want the cleanest first sync slice:
- make `SegmentEnvelope` mandatory
- defer `CollectionEnvelope`
- defer `ExportEnvelope`
- fold review state into segments initially

That gives the Apple client and backend one clean semantic sync unit to stabilize before expanding outward.
