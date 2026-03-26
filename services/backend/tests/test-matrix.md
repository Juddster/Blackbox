# First-Slice Backend Test Matrix

This matrix lists the minimum behavior cases that should pass before the first backend sync slice is considered usable.

It covers only:
- `SegmentEnvelope`
- push
- pull
- tombstones
- conflicts

## Push Cases

### P1. Create New Segment

- client pushes a valid new envelope
- backend accepts it
- backend returns initial server `syncVersion`
- segment later appears in pull

### P2. Update Existing Segment With Matching Base Version

- client pushes a valid update
- `baseSyncVersion` matches current server version
- backend accepts and increments server `syncVersion`

### P3. Mixed Batch: One Accepted, One Conflicted

- push request contains two changes
- one has matching `baseSyncVersion`
- one has stale `baseSyncVersion`
- response returns one accepted result and one conflict
- accepted change remains committed

### P4. Validation Failure

- push contains malformed envelope content
- backend rejects with validation error
- no successful semantic write occurs for that invalid change

### P5. Tombstone Push

- client pushes deletion state for an existing segment
- backend accepts
- tombstone remains visible to pull

## Pull Cases

### L1. Empty Pull

- client pulls with no new changes available
- backend returns `changes = []`
- cursor remains valid

### L2. Incremental Pull

- multiple changes exist after the supplied cursor
- backend returns ordered changes
- backend returns `nextCursor`

### L3. Pull Includes Tombstone

- a deleted segment exists in the feed after the cursor
- backend returns a tombstoned `SegmentEnvelope`

## Conflict Cases

### C1. Version Mismatch

- client pushes with stale `baseSyncVersion`
- backend returns `200 OK`
- conflict body contains current `serverEnvelope`

### C2. Deleted On Server

- client pushes an edit for a segment now deleted on server
- backend returns conflict with deleted server envelope

### C2a. Restore Attempt Against Tombstone

- client pushes a non-deletion write against a tombstoned server segment
- backend still returns `deletedOnServer`
- backend does not silently recreate the segment

### C3. User Beats System

- server has only system-authored interpretation change
- client has user-authored narrower interpretation
- conflict resolution path preserves user-authored interpretation semantics

## Transport / Error Cases

### T1. Malformed JSON

- backend returns request-level error
- client treats it as request failure, not sync conflict

### T2. Auth Failure

- backend returns `401` or `403` as appropriate

### T3. Temporary Server Failure

- backend returns `5xx`
- client treats as retryable service failure

## Cursor / Ordering Cases

### O1. No Skipped Changes

- accepted writes always become visible in pull ordering

### O2. Stable Cursor Progression

- repeated pulls with returned cursors advance deterministically

### O3. Retries Do Not Duplicate Durable Rows

- repeated identical accepted push does not create duplicate segment records

## Apple Integration Cases

### A1. Accepted Push Updates Local Sync State

- Apple client sends pending envelope
- backend accepts
- Apple client stores returned server `syncVersion`
- Apple client marks segment synced

### A2. Conflict Push Updates Local Sync State

- Apple client sends stale envelope
- backend returns conflict
- Apple client marks segment conflicted without corrupting local semantic state

### A3. Pull Reconciliation Updates Local Segment

- Apple client pulls a changed server envelope
- local SwiftData segment updates to match current server envelope
