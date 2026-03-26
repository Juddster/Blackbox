# Blackbox Conflict Resolution

This document defines the default v1 conflict handling policy.

## Goals

- Preserve local-first behavior.
- Keep the model current-state oriented.
- Prefer deterministic automatic resolution when it is safe.
- Protect user-authored meaning from being overwritten by weaker system inference.
- Match the first sync slice, which is segment-envelope-first.

## Resolution Rules

### 1. User Interpretation Beats System Interpretation

If one side has a user-authored classification and the other has only system-authored interpretation:
- keep the user-authored interpretation
- merge summary changes only if they do not contradict the segment identity

### 2. Server Versioning Is The Primary Conflict Trigger

A conflict exists when:
- the client pushes `baseSyncVersion = N`
- the server currently stores `syncVersion != N`

### 3. Envelope-Level Resolution First

For v1, resolve conflicts at the segment envelope level first rather than field-by-field CRDT-style merging.

This keeps the model simple and predictable.

Current scope clarification:
- this guidance applies first to `SegmentEnvelope`
- collections, exports, and richer review sync should not introduce more complex conflict machinery in the first sync slice

### 4. Tombstones Must Be Explicit

If one side deleted a segment:
- do not silently recreate it
- return the tombstone to the other side
- allow restoration only as an explicit future action, not an automatic merge

## Automatic Resolution Matrix

### Safe To Resolve Automatically

- system vs system interpretation changes
- summary-only refreshes where segment identity and timing are unchanged
- metadata-only changes folded into the segment envelope, such as `needsReview`, when no user override exists

### Should Prefer User State

- user-selected class vs inferred visible class
- user retitle vs system-generated title
- user correction of ambiguous segment

### May Require Client Review Later

- delete vs user edit
- trim or split vs stale server segment
- conflicting user edits from multiple devices
- any conflict where local segment replacement semantics no longer cleanly match the current server envelope

## Recommended Server Behavior

On conflict:
- reject the write with conflict metadata
- return the current server envelope
- do not attempt surprising silent merges server-side in v1

## Recommended Client Behavior

On conflict:
- try deterministic auto-resolution using the rules above
- if safe, resubmit the resolved envelope
- if unsafe, keep local state, mark sync as conflicted, and surface later review

Practical v1 implication:
- because review is currently expected to be folded into segment state rather than synced as a first-class review record, conflict handling should avoid inventing a separate review-merge subsystem too early

## Non-Goals

v1 should not attempt:
- multi-master CRDT semantics
- fine-grained merge histories
- user-visible diff timelines
