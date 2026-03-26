# Push / Pull Semantics

This document makes the first backend sync loop concrete enough to implement without inventing behavior endpoint by endpoint.

It is intentionally limited to the first required sync slice:
- `SegmentEnvelope`
- push
- pull
- conflicts
- tombstones
- cursors

## Goal

Define predictable backend behavior for:
- accepting client changes
- returning conflicts
- letting offline clients catch up incrementally

## Push Semantics

`POST /v1/sync/push`

### Request Expectations

The client sends:
- `deviceID`
- `accountID`
- one or more `changes`

Each change contains:
- `segmentEnvelope`
- `baseSyncVersion`

### Processing Model

For each incoming change:
1. validate payload shape
2. load current server envelope by `segment.id`
3. compare `baseSyncVersion` with current server version
4. either accept and advance version, or return a conflict with current server state

### Accepted Push Rules

If:
- the payload is valid
- the segment is new and `baseSyncVersion` is absent or equivalent to new-record semantics

or:
- the payload is valid
- `baseSyncVersion` matches the stored server `syncVersion`

then the backend should:
- persist the new current envelope
- increment to the next server-issued `syncVersion`
- return the accepted result with:
  - `segmentID`
  - `syncVersion`
  - `updatedAt`

### Conflict Rules

If:
- the payload is valid
- but `baseSyncVersion` does not match the stored server `syncVersion`

then the backend should:
- reject that change only
- return a conflict object with:
  - `segmentID`
  - `reason`
  - current `serverEnvelope`

The backend should not silently merge surprising changes in v1.

### Partial Acceptance

If a push request contains multiple changes:
- accepted changes should still commit
- conflicted changes should be returned individually
- invalid changes should fail clearly

The backend may later choose all-or-nothing batch semantics, but the first slice should prefer per-change results because they are easier for offline clients to recover from.

## Pull Semantics

`POST /v1/sync/pull`

### Request Expectations

The client sends:
- `deviceID`
- `accountID`
- optional `cursor`

### Response Semantics

The backend returns:
- ordered `changes`
- `nextCursor`
- `hasMore`

Each returned change contains:
- `segmentEnvelope`

### Ordering Requirement

Pull ordering must be stable enough that:
- an offline client can catch up deterministically
- tombstones are observed
- later cursors do not skip durable changes

The first slice does not require globally meaningful ordering beyond that.

### Cursor Requirement

The cursor should be:
- opaque to the client
- stable for incremental catch-up
- scoped to the account

The client should not infer semantics from cursor structure.

## Tombstone Semantics

Deleted segments remain visible to sync through tombstones.

The backend should:
- return tombstones through pull
- retain them long enough for reasonably offline clients to see them
- reject silent recreation when the current server state is deleted

For the first slice:
- tombstones ride inside the ordinary `SegmentEnvelope`
- `sync.isDeleted = true`
- `segment.lifecycleState = deleted`

## New Record Semantics

For a segment the server has never seen:
- treat the first accepted envelope as the durable current state
- assign initial server `syncVersion`
- include the accepted version in the response

The client-generated UUID remains the durable public identifier.

## Idempotency Direction

The first slice should be resilient to client retries.

Practical expectation:
- replaying the exact same accepted change should not create duplicate segment records
- retries after ambiguous network failures should converge to one current server envelope

Exact deduplication mechanics can remain implementation-specific at first as long as the observable result is stable.

## Conflict Reasons For First Slice

The minimal first conflict reasons should be:
- `versionMismatch`
- `deletedOnServer`

Validation failures should not appear as sync conflicts.

## Non-Goals

This document does not yet define:
- first-class collection sync loop
- first-class export sync loop
- dense observation upload semantics
- live share streaming semantics
