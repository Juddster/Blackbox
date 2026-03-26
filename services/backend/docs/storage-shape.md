# Backend Storage Shape

This document proposes the minimal backend-side persisted shape for the first sync slice.

It is not tied to a specific database engine.
Its purpose is to keep backend implementation simple while preserving the semantics already defined in the shared contracts.

## Goal

Store enough to support:
- durable `SegmentEnvelope` sync
- conflict detection
- tombstones
- cursor-based pull
- account scoping

Without prematurely modeling:
- collections
- exports
- dense observation upload
- rich history/version timelines

## Minimal Persisted Units

The first backend slice needs four persisted concerns:
- account-scoped current segment envelopes
- account-scoped sync feed ordering
- tombstones
- device cursor progression inputs

## 1. Segment Envelope Store

This is the primary durable store.

One current row or document per:
- `accountID`
- `segmentID`

### Suggested Stored Fields

- `account_id`
- `segment_id`
- `segment_payload`
- `interpretation_payload` nullable
- `summary_payload` nullable
- `sync_version`
- `is_deleted`
- `last_modified_at`
- `last_modified_by_device_id`
- `created_at`
- `updated_at`

### Notes

- store the current effective envelope only
- do not require historical envelope versions in v1
- `segment_payload`, `interpretation_payload`, and `summary_payload` may be stored either decomposed or as canonical JSON blobs depending on backend implementation choice

## 2. Sync Feed Store

The pull endpoint needs a stable ordered feed of durable changes.

This can be represented by:
- a dedicated change-feed table
- or an equivalent monotonically ordered update stream

### Suggested Stored Fields

- `account_id`
- `feed_position`
- `segment_id`
- `sync_version`
- `changed_at`
- `is_deleted`

### Notes

- `feed_position` must be monotonic within an account scope
- pull cursors can be based on this feed position
- the feed only needs to support deterministic incremental catch-up, not user-visible history browsing

## 3. Tombstone Retention

Deleted segments should remain pull-visible for offline clients.

Two workable shapes:
- keep deleted segment envelopes in the primary store with `is_deleted = true`
- or keep dedicated tombstone rows linked to the deleted segment ID

For v1, the simpler direction is:
- keep tombstones in the same current-envelope store
- emit them into the sync feed like ordinary changes

### Required Tombstone Fields

- `account_id`
- `segment_id`
- `sync_version`
- `last_modified_at`
- `last_modified_by_device_id`
- `is_deleted = true`

## 4. Optional Device Sync State

The backend may also persist compact per-device sync state if it helps observability or replay safety.

Possible fields:
- `account_id`
- `device_id`
- `last_seen_at`
- `last_pull_cursor`

This is optional for the first slice because the client already carries the cursor.

## Write Path Expectations

When a push is accepted:
1. update or insert the current segment-envelope row
2. assign the next `sync_version`
3. append one feed entry for pull

When a tombstone push is accepted:
1. mark the current segment-envelope row as deleted
2. assign the next `sync_version`
3. append one deleted feed entry

## Read Path Expectations

For pull:
- resolve the account-scoped cursor into a feed position
- read forward in stable order
- load the matching current envelopes
- return them as `changes`

The backend does not need to reconstruct older historical envelope versions for the first slice.

## Constraints

- `segment_id` uniqueness must be scoped by `account_id`
- `sync_version` must advance monotonically per segment envelope
- feed ordering must not skip accepted durable changes
- deleted envelopes must remain visible long enough for reasonably offline clients

## Non-Goals

This storage shape does not yet define:
- first-class collection persistence
- export artifact persistence
- support-evidence storage
- live sharing sessions
- event-sourced edit history
