# First Sync Slice

This document defines the backend-facing scope of the first actual sync implementation.

It intentionally narrows the problem so backend implementation can start without importing unnecessary future scope.

## Goal

Implement the smallest useful durable sync slice that supports:
- local-first Apple client behavior
- durable segment history backup
- basic conflict detection
- offline catch-up

## Included In First Sync Slice

### 1. SegmentEnvelope

Mandatory.

Includes:
- segment record
- current interpretation state
- current summary state
- shared sync metadata

### 2. Push

Mandatory.

Support:
- client push of changed segment envelopes
- monotonic version handling
- conflict response with current server envelope

### 3. Pull

Mandatory.

Support:
- incremental pull by opaque cursor
- stable ordering sufficient for offline catch-up

### 4. Tombstones

Mandatory.

Support:
- deleted segments represented explicitly
- tombstones retained long enough for offline clients to observe deletion

## Explicitly Deferred From First Sync Slice

### Collections

Deferred unless implementation pressure makes them essential sooner.

### Export Sync

Deferred.

### First-Class Review Sync

Deferred.

For the first slice, review should remain folded into segment state.

### Dense Observation Upload

Deferred.

### Retained Support Evidence Upload

Deferred except for later selective cases.

### Live Sharing

Deferred.

## Backend Data Responsibilities In This Slice

The backend must support:
- account scoping
- segment-envelope durability
- sync version incrementing
- cursor-based pull
- conflict payload return
- tombstone persistence

The backend does not yet need to support:
- advanced merge histories
- collection membership storage
- export artifact storage
- live-trip sharing state

## Recommended First Backend Interfaces

At minimum:
- `POST /v1/sync/push`
- `POST /v1/sync/pull`

That is enough to validate:
- payload compatibility
- offline sync loop
- conflict semantics

## Why This Narrowing Matters

If the backend starts with too much scope, it will likely:
- harden assumptions too early
- force client decisions before the Apple side stabilizes
- spend effort on secondary semantics before segment sync is proven

This first slice is intentionally not the final sync model.
It is the first durable path that proves the local-first architecture works.
