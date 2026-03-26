# Client Local Sync State

This document separates shared sync-contract fields from client-local operational sync state.

It exists because the Apple client needs local workflow state that the backend contract should not absorb.

## Goal

Keep a clean distinction between:
- synced semantic envelope state shared with the backend
- local operational state used by the client to manage pending uploads, conflicts, and retries

## Shared Sync Metadata

Inside `SegmentEnvelope.sync`, the shared fields are:
- `lastModifiedByDeviceID`
- `lastModifiedAt`
- `syncVersion`
- `isDeleted`

These fields are part of the client/server contract.

### Important Rule

`syncVersion` is:
- server-issued
- monotonic per segment envelope
- stored locally as the client's last known server version

The client must not treat it as a locally incremented edit counter.

## Client-Local Operational State

The Apple client may persist additional local-only state such as:
- `disposition`
  - pending upload
  - synced
  - conflicted
- `lastSyncError`
- local retry bookkeeping
- local last-attempt timestamps

These fields are valid and useful locally, but they are not part of `SegmentEnvelope.sync`.

## Recommended Apple Shape

The Apple client should model:
- shared sync metadata separately from
- local operational sync workflow state

That can be done as:
- one local record with clearly separated field groups
- or two local records if that is cleaner in SwiftData

The key requirement is semantic separation, not a specific storage class layout.

## Local Edit Behavior

When the user or system changes a local segment:
- update local semantic state
- mark local operational sync state as pending
- keep the stored last known server `syncVersion` unchanged until a successful server acceptance returns a new one

Do not bump `syncVersion` locally just because the client edited the segment.

If the current conflict is `deletedOnServer`:
- do not treat ordinary local requeue as an automatic restore path
- keep the conflict explicit until the product has a deliberate restore action

## Why This Matters

If the client increments `syncVersion` locally:
- push conflict handling becomes ambiguous
- the backend contract is misrepresented
- client and server can disagree about what version numbers mean

If local-only workflow state leaks into the shared envelope:
- backend assumptions become polluted with Apple-specific implementation details
- cross-platform sync semantics get harder to preserve later
