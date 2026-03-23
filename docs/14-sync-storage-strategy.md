# Blackbox Sync And Storage Strategy

This document turns the chosen `Option B: Balanced Local-First Cloud` into a more concrete storage and sync strategy.

It is still not an implementation-level backend spec.

Its purpose is to define:
- what data should live locally
- what data should sync
- when syncing should happen
- what should be temporary versus durable
- how development replay data differs from product data

## Scope Basis

This document assumes:
- [08-v1-scope-spec.md](/Users/judd/DevProjects/Blackbox/docs/08-v1-scope-spec.md)
- [09-v1-requirements-spec.md](/Users/judd/DevProjects/Blackbox/docs/09-v1-requirements-spec.md)
- [13-schema-draft.md](/Users/judd/DevProjects/Blackbox/docs/13-schema-draft.md)

## Strategy Summary

Blackbox should use:
- local-first operational storage
- cloud-backed durable semantic sync
- selective and adaptive support-data upload
- separate handling for development replay datasets

The key rule is:
- local correctness first
- durability second
- efficiency always

## Storage Layers

The practical storage model should have four layers.

### 1. Live Observation Buffer

Purpose:
- hold dense incoming data needed for active inference and short-term replay

Examples:
- frequent location samples
- motion/activity samples
- pedometer-related samples
- heart-rate samples
- device/connectivity state samples

Characteristics:
- high volume
- local-first
- mostly temporary

### 2. Retained Support Evidence

Purpose:
- keep selected derived support artifacts long enough to support unsettled segments, short/medium-term review, and practical replay

Examples:
- simplified route geometry
- selected speed/elevation profile
- selected heart-rate series
- confidence-supporting evidence summaries

Characteristics:
- lower volume than raw observations
- retained for a medium window
- deleted or compacted once no longer useful

### 3. Durable Semantic History

Purpose:
- persist the meaningful long-term record

Examples:
- segments
- interpretations
- summaries
- quality state
- annotations
- collections
- collection membership
- saved exports

Characteristics:
- durable
- synced
- the main user-facing history layer

### 4. Development Replay Datasets

Purpose:
- support classifier and segmentation iteration during development

Examples:
- multi-stream recorded days
- labeled ranges for known activities
- replayable real-world capture sets

Characteristics:
- separate from ordinary product history
- should not be confused with end-user durable semantic storage
- may live locally, externally, or in a dedicated dev storage path

## What Stays Local

These should primarily remain local:
- dense live observations
- transient diagnostics
- operational sync cursors
- temporary replay buffers
- device-specific policy state where cross-device sync is not yet essential

Why:
- volume
- privacy sensitivity
- cost control
- local-first correctness

## What Syncs Durably

These should sync durably to cloud:
- segments
- current interpretations
- current summaries
- quality state
- annotations
- collections
- collection membership
- active review state
- saved exports

Why:
- this is the durable meaning of the user’s history
- this is what should survive device loss
- this is what later web or multi-device access will depend on

## What Syncs Selectively

These may sync when justified:
- retained support evidence
- active in-progress support snapshots
- limited device records
- some compact resolved review metadata

Why:
- they can be useful for recovery, sharing in progress, or short-term reinterpretation
- but they should not become permanent baggage by default

## Settling Window Strategy

A segment should move through roughly three states:

### 1. Active

Meaning:
- still being recorded or very recently ended

Storage behavior:
- raw observation buffer retained
- support evidence retained
- adaptive sync possible

### 2. Unsettled

Meaning:
- no longer active, but still recent enough that review, correction, or ambiguity resolution is plausible

Storage behavior:
- support evidence retained
- durable semantic state synced
- review and edits remain expected

### 3. Settled

Meaning:
- the segment is old enough that the product no longer expects ongoing reinterpretation

Storage behavior:
- durable semantic state persists
- support baggage is compacted or deleted unless it still serves a clear purpose

## Sync Triggers

Sync should be opportunistic and triggered by combinations of:
- app wake opportunities
- background URL session opportunities
- connectivity improvements
- charging state
- elapsed time since last successful sync
- amount of unsynced durable data
- amount of unsynced important in-progress data

## Sync Modes

The current policy model suggests at least three behavior modes.

### 1. Aggressive

Behavior:
- sync sooner
- accept more cellular usage
- upload in-progress activity updates more readily

Best for:
- important live activities
- users prioritizing durability over battery

### 2. Balanced

Behavior:
- the default mode
- sync durable history opportunistically
- sync in-progress activity data when conditions are reasonable

### 3. Battery-Preserving

Behavior:
- minimize active uploads
- prefer better network conditions
- defer non-essential transfers more often

## In-Progress Activity Sync

### Product Goal

Do not leave long important activities entirely unsynced when there are good chances to back them up.

### Proposed Strategy

- upload selectively during long or important activities
- lower the upload threshold as:
  - time since last upload grows
  - unsynced value grows
  - user intent suggests the activity matters

### Data To Sync During Activity

Prefer:
- checkpoints
- compact support summaries
- current route snapshots
- current segment state

Avoid by default:
- full dense raw streams

## Network Policy

The sync system should distinguish between:
- Wi-Fi
- non-Wi-Fi
- constrained/expensive conditions
- roaming-like situations where reliably inferable

### Practical Policy

- durable semantic sync can happen broadly in small amounts
- heavier transfers should prefer better conditions
- roaming should be treated conservatively unless user settings say otherwise

## Development Replay Data Strategy

This is separate from user-facing product retention.

### Recommended Rule

Development recordings should not be mixed into ordinary production history structures.

### Recommended Handling

- separate storage path
- separate labeling metadata
- replay tooling that can inject streams back through segmentation/classification
- ability to mark known activity ranges for evaluation

### Why This Matters

Development replay data has a different purpose:
- model iteration
- regression testing
- classifier tuning

Not:
- long-term personal semantic history

## Watch / Phone Storage Relationship

Because the watch may collect useful or standalone data:
- watch-originated data may exist before reconciliation with phone
- some records may initially exist only on one device
- reconciliation should prefer consistency of semantic history over perfect raw preservation

### Practical Rule

- phone remains the main durable semantic store in v1
- watch can hold temporary local capture until transfer/reconciliation happens

## Export Storage Strategy

Saved exports should:
- be durable
- be synced
- retain both enough rendered payload and enough metadata/reference context to remain viewable and re-shareable

Exports should not:
- become the primary historical record
- replace the underlying semantic objects

## Failure Handling

### If Cloud Sync Fails

- local history remains authoritative
- sync retries later
- UI should not behave as though the history was lost

### If Support Data Is Lost Before Settling

- the product may lose some later edit/review power
- but durable semantic history should still remain usable

### If Watch Transfer Is Delayed

- phone timeline may temporarily be incomplete
- reconciliation should fill gaps later without corrupting settled history

## Recommended v1 Defaults

- local-first always
- balanced sync mode by default
- durable semantic sync enabled
- in-progress sync selective and adaptive
- support evidence retained through the unsettled window
- support evidence compacted after settlement unless still justified
- development replay data stored separately from ordinary user history

## Open Strategy Questions

### 1. Settling Window Length

How long should a segment remain unsettled before support baggage is compacted?

Possible stances:
- short window, such as days
- medium window, such as weeks
- configurable by user

**JF Note**
medium
**End JF Note**

Updated conclusion:
- A medium settling window is the right default.
- In practice, that means support baggage survives long enough for realistic review and correction, but not so long that old history accumulates indefinite classifier baggage.

### 2. In-Progress Importance Signal

What should make an activity important enough for more aggressive in-progress sync?

Possible signals:
- user explicitly marks it
- long duration
- unusual distance
- manual share/live-share state

**JF Note**
All of the above
**End JF Note**

Updated conclusion:
- In-progress importance should be triggered by multiple signals rather than a single rule.
- A segment/activity can become more aggressively sync-worthy because of:
- explicit user intent
- long duration
- unusual distance or scale
- active share/live-share behavior

### 3. Replay Dataset Storage

Should development replay datasets live:
- inside the app sandbox
- in a separate developer-only store
- in both, depending on workflow

**JF Note**
I think this is a workflow issue. Whatever is most conducive for iterating and fine tunning the app's classifier and in improvement general.
**End JF Note**

Updated conclusion:
- Replay dataset storage should remain workflow-driven.
- The important requirement is not where it lives in principle, but that the setup makes classifier iteration and regression testing fast and practical.
