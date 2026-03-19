# Blackbox Retention And Sync Brainstorming

This document holds the retention and sync behavior branch for Blackbox.

The goal here is to reason about:
- what should be kept
- at what fidelity
- for how long
- where it should live
- when and how it should upload or sync

This is still brainstorming, not implementation planning.

## Brainstorming Branch 4: Retention And Sync Behavior

### Core Objective

The retention and sync model should support all of the following:
- passive always-on recording
- enough preserved evidence for later reinterpretation
- reasonable battery and bandwidth usage
- reasonable storage cost
- local-first correctness
- future cloud backup and multi-device access
- a clean path toward richer export and multi-user possibilities later

### Starting Principles

The earlier brainstorming already suggests several principles:
- nothing meaningful is ever deleted
- broad raw retention forever is not the goal
- preserve enough evidence to allow later recategorization and summary recomputation
- local capture and interpretation should work even if sync is delayed
- cloud is secondary early on

### Likely Retention Layers

The most workable mental model is probably layered retention.

Possible layers:
- transient raw support data
- retained support data
- durable segment summaries
- durable collections
- durable exports
- optional edit and review history

### 1. Transient Raw Support Data

This is the highest-volume data and the least likely to deserve indefinite retention in raw form.

Examples:
- dense motion samples
- dense intermediate location observations
- temporary classification support signals
- high-frequency sensor bursts used during uncertain activity detection

Likely purpose:
- immediate inference
- short-term reprocessing
- recovery from recent misclassification

Possible policy:
- keep locally for a short window
- optionally upload during in-progress or ambiguous activities if useful
- drop or compress later once enough meaning has been extracted

### 2. Retained Support Data

This is the subset of evidence worth keeping beyond the shortest window because it may support later reinterpretation.

Examples:
- route geometry at useful resolution
- timestamps
- pause structure
- speed profile
- elevation profile
- heart rate summary or selected heart rate series
- quality flags
- confidence-related signals

This layer is probably the real answer to your "keep enough data for recategorization" requirement.

### 3. Durable Segment Summaries

This is the main long-lived user-facing history.

Examples:
- start/end time
- visible class
- title
- notes
- distance
- duration
- summary route
- summary health context
- quality state
- whether it belongs to a collection

This is likely the core of the timeline and collection experience.

### 4. Durable Collections

Collections likely deserve full retention because they represent user-curated meaning.

Examples:
- named outings
- grouped travel days
- multi-sport events
- curated packages for later sharing

Because collections are user-authored or user-accepted meaning, they likely deserve durable treatment even if some underlying support data is later compacted.

### 5. Durable Exports

Exports may be saved artifacts rather than purely transient renders.

Potential reasons to retain them:
- historical record of what was published/shared
- quick re-share later
- "magazine of stories" concept
- avoid regenerating old exports exactly the same way

### 6. Edit And Review History

This is a judgment call, but there is a strong case for keeping it.

Reasons:
- preserve the meaning of user intervention
- allow future debugging
- support trust and reversibility

Potential downside:
- more storage and conceptual complexity

My current instinct:
- keep it, but mostly as structured metadata rather than huge payloads

## Local vs Cloud

### Local-First Principle

The app should behave correctly even when:
- offline
- on poor connectivity
- roaming
- intentionally prevented from uploading

This means:
- local storage is not a temporary cache in front of the cloud
- local storage is the primary operational store

### Cloud Early On

Early cloud behavior likely needs to justify itself by:
- backup
- recovery
- long-term durability
- future web access
- future reprocessing

Not necessarily by:
- primary classification
- real-time product correctness

### Cloud Later

Later, cloud may also support:
- multi-device sync
- shared infrastructure for many users
- richer exports and history access
- heavier retrospective analysis

### Storage Destination Possibilities

The earlier discussion suggests several future possibilities:
- app-managed cloud backend
- user-owned storage such as Google Drive or similar
- hybrid model

This choice has strong privacy and operational implications, but may not need to be fixed yet at the brainstorming level.

## Sync Behavior

### Default Sync Model

A likely default is opportunistic sync:
- capture locally first
- upload when conditions are acceptable
- defer when network/battery conditions are poor

Potential signals:
- connectivity quality
- Wi-Fi vs cellular
- roaming
- battery level
- Low Power Mode
- charging state
- whether the data is time-sensitive or likely to be valuable if backed up sooner

### In-Progress Activities

There may be special retention/sync behavior for active in-progress segments.

Possible reasons to upload earlier:
- preserve data in case the device is lost or dies
- support short-term reprocessing
- maintain safety of long important outings

Possible reasons not to:
- battery cost
- bandwidth cost
- poor connectivity

This may call for special policies on:
- long rides
- hikes
- travel days
- flights

### Battery-Aware Sync

Earlier discussion strongly points toward policy-driven sync behavior.

Possible model:
- aggressive
- balanced
- battery-preserving

And overrides based on:
- Low Power Mode
- battery thresholds
- charging state
- user override

### Conflict And Reprocessing Questions

If the system later improves its classification or summary logic, what happens to old data?

Possible approaches:
- never reprocess old segments automatically
- reprocess derived fields but preserve user edits
- create a new interpretation while keeping the prior one

This matters because retention is partly about enabling better future meaning without corrupting user history.

### Upload Units

Conceptually, what should sync in units of?

Possibilities:
- raw observations
- support-data batches
- segments
- collections
- edits
- exports

My current instinct:
- support-data batches for short-lived evidence
- segments and edits as the main durable sync units
- collections and exports as separate durable sync units

## Recommended Retention Strategy So Far

At a conceptual level, a likely good strategy is:

- keep dense raw support data briefly and locally
- retain selected support evidence longer when needed for reinterpretation
- keep segment summaries durably
- keep collections durably
- keep exports durably when explicitly saved/published
- keep edit/review history as structured metadata
- sync opportunistically, not as a precondition for correctness

This seems consistent with your original goals and later refinements.

## Questions For This Branch

### 1. Raw Data Window

How do you feel about this general direction:
- dense raw support data kept only for a limited window
- selected support evidence retained longer
- semantic segment history kept durably

**JF Note**
Sounds good to me
**End JF Note**

Updated conclusion:
- The layered retention model is acceptable as the working direction.
- Dense raw support data should be temporary, while selected support evidence and semantic history remain durable.

### 2. In-Progress Uploading

For long important activities, should the app sometimes upload during the activity rather than waiting until later?

Examples:
- long ride
- hike
- travel day

Possible stances:
- no, finish locally first
- yes, opportunistically when conditions are good
- yes, especially for user-marked important activities

**JF Note**
yes, opportunistically when conditions are good. Lower the conditions bar the longer the time since last upload and the more data we accumulate. This is useful mainly for sharing an activity in progress, so that might influence what exactly we upload even when conditions are not ideal.
**End JF Note**

Updated conclusion:
- In-progress uploading should be adaptive rather than binary.
- The system should become more willing to sync as the amount of unsynced valuable data grows or the time since the last upload increases.
- In-progress sharing may justify uploading a slightly different or more immediately useful subset than ordinary background retention does.

### 3. Wi-Fi vs Cellular vs Roaming

How opinionated should sync policy be about network type?

Possible stances:
- sync on any connection by default
- prefer Wi-Fi for heavier uploads
- be conservative on roaming unless overridden

**JF Note**
All of the above and see my previous comment.
**End JF Note**

Updated conclusion:
- Sync policy should be network-aware and graduated rather than governed by one fixed rule.
- Light sync may happen broadly, heavier sync should prefer Wi-Fi, and roaming should be treated conservatively unless the user overrides.

### 4. Reprocessing Older History

If the heuristics improve later, should the app be able to reinterpret old segments?

Possible stances:
- yes, but never overwrite user edits
- yes, only when explicitly requested
- no, preserve history exactly as originally inferred

**JF Note**
no, preserve history exactly as originally inferred (and, of course, if edited then preserve that too)
**End JF Note**

Updated conclusion:
- Older history should not be automatically reinterpreted.
- The historical record should preserve both the original system inference and any later user edits.
- This is a strong archival principle and an important product identity choice.

### 5. Export Retention

Should saved exports be kept as part of the durable record by default?

**JF Note**
Yes
**End JF Note**

Updated conclusion:
- Saved exports should be part of the durable record by default.

### 6. Storage Destination Direction

At this brainstorming stage, which direction feels most aligned?

Possible directions:
- app-managed cloud backend
- user-owned cloud storage
- hybrid, decide later

**JF Note**
hybrid, decide later
**End JF Note**

Updated conclusion:
- Storage destination should remain open between app-managed, user-owned, and hybrid models.
- The product should avoid assumptions that lock it into one storage model prematurely.

## Retention And Sync Resting State

This branch now has a stable first-pass direction.

### Recommended Retention Model

- keep dense raw support data only for a limited local window
- retain selected support evidence when needed for later understanding and recategorization
- keep semantic segment history durably
- keep collections durably
- keep saved exports durably
- keep edit and review history as lightweight structured metadata

### Recommended Sync Model

- local-first correctness
- opportunistic background sync
- adaptive in-progress uploads for long or important activities
- lighter sync allowed more broadly
- heavier sync biased toward better network conditions
- conservative roaming behavior unless explicitly overridden

### Strong Product Principle Confirmed Here

One particularly important decision from this branch:

- history should be preserved as originally inferred
- user edits should also be preserved
- later heuristic improvements should not silently rewrite the past

That is a meaningful philosophical choice. It makes Blackbox feel more like a journal or recorder than a constantly self-rewriting analytics system.

### Practical Implication

Because old history is not meant to be silently reinterpreted:
- support evidence still matters for user-driven edits and splits
- edit history matters more
- exports can become part of the durable story archive

### Storage Direction

The storage strategy should remain flexible enough to support:
- app-managed backend later
- user-owned storage later
- hybrid architecture later

Without forcing that decision now.

## Brainstorming Set Status

At this point, the four main branch docs now cover:
- activity inference realism
- rough data model shaping
- UI concepting
- retention and sync behavior

This is probably enough conceptual coverage to move into either:
- a synthesis document
- rough architecture discussion
- actual planning/spec work
