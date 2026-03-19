# Blackbox Architecture Overview

This document translates the current product synthesis into a rough architecture view.

It is still intentionally high level. It is not yet:
- a detailed technical specification
- a schema definition
- an API contract
- an implementation plan

Its purpose is to identify the major system parts, their responsibilities, and the boundaries that matter.

## Architectural Goal

The architecture should support a product that is:
- passive by default
- local-first in operation
- segment-centric in meaning
- uncertainty-aware
- efficient in retention and sync
- flexible enough to grow into richer health data, web access, Android, and broader cloud support later

## System Overview

At a high level, Blackbox appears to need five major layers:
- on-device capture
- on-device interpretation
- local persistence
- sync/export services
- cloud durability and access layer

**JF Note**
Not sure what this means. In general, cloud is not optional
**End JF Note**

Updated conclusion:
- Cloud should not be described as optional at the product level.
- A better distinction is:
- cloud is part of the product architecture
- cloud is not required for immediate on-device correctness at runtime

These layers should be loosely coupled enough that:
- the phone can keep working when cloud is unavailable
- classification logic can evolve without rewriting the whole app
- retention policy can compact support data without breaking the user-facing history
- future platforms can share the conceptual model even if implementations differ

## Primary Runtime Components

### 1. Sensor Capture Layer

Purpose:
- collect data from iPhone, Apple Watch, Health, and future sources

Responsibilities:
- ingest location and motion signals
- ingest health-related signals
- ingest device-state context such as battery, charging, and connectivity
- normalize incoming readings into a common observation format
- tolerate sparse, degraded, or intermittent signals

Design implication:
- source-specific adapters will likely sit here
- this layer should know how to capture data, not how to interpret life events

### 2. Observation Store

Purpose:
- hold raw and semi-processed support data locally

Responsibilities:
- persist recent observations
- support time-based lookup for inference
- support compaction and expiration rules
- separate transient dense data from longer-retained support evidence

Design implication:
- this is the main buffer between real-world sensing and higher-level meaning
- retention policy acts strongly on this layer

### 3. Activity Segmentation Engine

Purpose:
- turn streams of observations into candidate segments and pause events

Responsibilities:
- detect segment boundaries
- detect pauses within segments
- detect transitions between likely activity contexts
- produce candidate segment objects with time bounds

Design implication:
- segmentation should be distinct from classification
- this engine answers "where are the boundaries?" more than "what exactly is this activity?"

### 4. Classification And Quality Engine

Purpose:
- assign meaning and quality state to segments

Responsibilities:
- assign visible activity class
- keep ambiguity and confidence state
- assign quality state such as trusted, degraded, implausible, or needs review
- optionally keep candidate subtypes internally
- decide when to create review items

Design implication:
- this layer should be conservative
- it should be able to operate on incomplete data
- it should not require cloud availability

### 5. Summary And Derivation Engine

Purpose:
- compute durable segment and collection summaries

Responsibilities:
- compute duration, distance, route summary, elevation gain, pause counts, health summaries, and other derived fields
- recompute summaries after user edits such as split or trim
- produce collection-level combined summaries

Design implication:
- this engine turns interpreted history into UI-ready and export-ready data

### 6. Local Domain Store

Purpose:
- persist the durable semantic model locally

Responsibilities:
- store segments
- store interpretations
- store summaries
- store collections
- store annotations
- store review items
- store edit history
- store saved exports metadata

Design implication:
- this is the app's primary operational record of meaning
- timeline, review, collections, and export surfaces should mostly read from here

### 7. Policy Engine

Purpose:
- decide how aggressively the app captures, retains, syncs, and notifies

Responsibilities:
- apply battery mode rules
- react to Low Power Mode
- react to charging state
- react to connectivity quality
- apply roaming/Wi-Fi/cellular preferences where detectable
- decide when to compact old support data
- decide when to sync in-progress activities

Design implication:
- policies should be centralized rather than scattered across capture, sync, and UI code

### 8. Sync Engine

Purpose:
- move durable and selected transient data to external storage when appropriate

Responsibilities:
- package upload units
- prioritize what to sync first
- defer when conditions are poor
- retry safely
- keep local-first correctness intact
- sync segments, edits, collections, exports, and selected support evidence

Design implication:
- sync should be opportunistic and policy-driven
- it should not be the source of truth for current app behavior

### 9. Export Engine

Purpose:
- generate shareable artifacts from segments or collections

Responsibilities:
- render export variants
- allow field/attribute selection
- save exports when desired
- support destination-specific presentation later

Design implication:
- export generation should be separate from sync
- sharing is a publishing concern, not a storage concern

### 10. User Interface Layer

Purpose:
- present semantic history and let the user correct or curate it

Main surfaces:
- timeline
- segment detail
- collection detail
- filtered review states
- export flow
- settings/policies
- watch activity-aware UI

Design implication:
- the UI should mostly consume stable domain objects, not raw sensor streams

## Proposed Data Flow

At a high level, the likely flow is:

1. Sensors and source adapters produce observations.
2. Observations are normalized and persisted locally.
3. Segmentation identifies candidate segments and pause events.
4. Classification assigns visible class, confidence, and quality state.
5. Summary derivation computes durable segment summaries.
6. The local domain store becomes the source for timeline, collections, review, and export.
7. Policy decisions determine compaction, upload timing, and notification behavior.
8. Sync moves appropriate data outward when conditions allow.
9. Export produces user-facing share artifacts from segments or collections.

## Recommended Architectural Boundaries

The following boundaries seem especially important.

### Capture vs Interpretation

Why it matters:
- hardware and source integrations will evolve independently of inference rules

Recommendation:
- keep sensor/source adapters separate from segmentation/classification logic

### Segmentation vs Classification

Why it matters:
- "where the activity starts and ends" is a different problem from "what the activity is"

Recommendation:
- keep boundary detection and activity labeling as distinct subsystems

### Support Data vs Durable Semantic Data

Why it matters:
- retention policy acts very differently on these layers

Recommendation:
- keep observation/support storage clearly separate from durable segment/collection storage

### Domain Model vs UI View Models

Why it matters:
- the timeline and watch UI will likely need tailored representations

Recommendation:
- avoid letting UI structure define the underlying domain model

### Sync vs Export

Why it matters:
- upload/backups and human sharing are different concerns with different lifecycles

Recommendation:
- keep sync infrastructure separate from export generation and sharing flows

## Suggested Platform Shape

### iPhone App

Likely central responsibilities:
- primary sensor fusion
- local domain store
- segmentation/classification
- timeline and editing UI
- sync/export orchestration

### Apple Watch App

Likely responsibilities:
- capture watch-native signals
- show activity-aware current UI
- allow quick correction of current inferred activity
- hand data and user actions back to the phone-centric system

The watch should probably not be treated as the primary brain in v1, but it also should not be treated as a thin peripheral.

**JF Note**
Actually, watch app should be able to record an activity even when the iPhone is not arround. Just like workout and mapping apps work on the watch with no iphone near by.
**End JF Note**

Updated conclusion:
- The watch should support standalone activity recording when the iPhone is not nearby.
- That implies a more precise architecture:
- the iPhone remains the primary integration and history-management device
- the watch is a partially autonomous edge recorder with its own capture, temporary storage, and current-activity UI
- later reconciliation between watch and phone becomes an architectural requirement


### Cloud Layer

Early responsibilities:
- backup and durability
- future recovery
- future web access
- future multi-device portability

Clarification:
- cloud is architecturally present from the beginning
- but the app should not depend on cloud round-trips for basic sensing, inference, or immediate UX correctness

Later responsibilities:
- multi-user tenancy
- broader data access surfaces
- heavier analytics if ever desired

### Watch And Phone Relationship

Because of the standalone-watch requirement, the architecture likely needs to treat phone and watch as cooperating local nodes rather than a strict parent-child pair.

Practical implication:
- both devices may capture overlapping or complementary observations
- either device may temporarily be the only active recorder
- reconciliation logic will eventually need to decide how to merge or prefer data from both devices without corrupting the semantic history

## Failure And Degradation Philosophy

The system should degrade gracefully when:
- location becomes unreliable
- watch data is unavailable
- cloud sync is unavailable
- battery is low
- connectivity is poor

Graceful degradation means:
- preserve what can still be known
- lower confidence when appropriate
- create review items when ambiguity matters
- continue functioning locally

## Architecture Risks To Watch

These look like the main architectural risks at this stage.

### 1. Overcoupling Raw Capture To UI Semantics

If the product directly binds sensor structure to UI surfaces, it will become fragile quickly.

### 2. Letting Sync Become A Hard Dependency

If cloud sync becomes required for correctness, the local-first product promise breaks.

### 3. Mixing Temporary Evidence With Durable Meaning

If support baggage and durable semantic history are stored without clear separation, retention and compaction become messy.

### 4. Underestimating Segment Boundary Complexity

If segmentation is treated as trivial, the whole downstream model becomes noisy.

### 5. Treating Review As An Afterthought

Because ambiguity and quality issues are core to the product, review state should be part of the architecture, not just the UI.

## Reasonable Next Technical Documents

After this architecture overview, the most natural follow-up documents would be:
- a v1 scope/spec
- a concrete domain model/schema draft
- a sensor/source capability assessment for iPhone + Apple Watch
- a sync/storage strategy decision record
- a UI information architecture or screen map
