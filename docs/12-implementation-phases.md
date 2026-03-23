# Blackbox Implementation Phases

This document proposes a phased implementation path for Blackbox v1.

It is not a sprint plan and not a ticket breakdown.

Its purpose is to answer:
- what should be built first
- what dependencies exist between feature areas
- what should be proven before investing in more layers
- how to keep the project from overbuilding too early

## Scope Basis

This document assumes:
- [08-v1-scope-spec.md](/Users/judd/DevProjects/Blackbox/docs/08-v1-scope-spec.md)
- [09-v1-requirements-spec.md](/Users/judd/DevProjects/Blackbox/docs/09-v1-requirements-spec.md)
- [10-domain-model-draft.md](/Users/judd/DevProjects/Blackbox/docs/10-domain-model-draft.md)
- [11-apple-device-capabilities.md](/Users/judd/DevProjects/Blackbox/docs/11-apple-device-capabilities.md)

## Guiding Principle

The build order should optimize for proving the core product loop early:

- capture passively
- create plausible segments
- show them on a timeline
- let the user correct them

Everything else should come after that loop is real.

## Proposed Phases

## Phase 0: Foundations

### Goal

Create the minimum technical foundation required to start building and testing the core loop.

### Likely Deliverables

- project scaffolding
- local persistence foundation
- basic domain model implementation
- settings/policy skeleton
- logging and diagnostics scaffolding

### Why This Comes First

Without a clean local data foundation, every later capability becomes harder to validate.

### Exit Criteria

- app project structure exists
- local storage can persist domain objects
- app can run with test/demo data

## Phase 1: Passive Capture On iPhone

### Goal

Prove that the iPhone can collect the core signals needed for the passive loop.

### Likely Deliverables

- background location capture
- motion/activity capture
- pedometer/floor-related capture where available
- heart-rate ingestion path where available through HealthKit
- observation persistence
- basic quality logging for missing/degraded signals

### Important Questions To Answer

- What capture mix gives acceptable coverage without obviously bad battery behavior?
- How good are the raw signals for ordinary movement reconstruction?
- How weak are indoor/non-location movement cases?

### Exit Criteria

- the app can collect and persist useful observation streams from real usage
- data survives app restarts and intermittent connectivity

**JF Note**
one of the practical challenges in developing location/motion based apps is testing them with real data. This is especially true with Blackbox. While you could eazyly generate a simulatet series of time based locations, for Blackbox it is not nearly enough. We need multiple streams of timestamped data. Location, motion, pedometer, heart rate, etc to all be funnled into the classifier. So, for development, I think we'll need to record days' worth of data and then use those streams while developing the clasifier. Otherwise, itteration will take days or even weeks. I'm not hiking or traveling every day, afterall. We need to capture the data when it happens and store it in a file or database with some indication what activities it includes with start and end times.

I'd say this is phase 1.5. Makes sense?
**End JF Note**

Updated conclusion:
- Yes, this absolutely deserves its own explicit early phase.
- Blackbox is not the kind of product where synthetic toy data is enough.
- A reusable real-world dataset/replay pipeline is part of the critical path for developing and tuning the classifier.

## Phase 1.5: Real-World Dataset Capture And Replay

### Goal

Create a development workflow that allows classifier and segmentation work to iterate on recorded real-world multi-stream data rather than waiting for new live activities every time.

### Likely Deliverables

- raw multi-stream capture format or local database for development recordings
- ability to record days of real-world sensor streams
- timestamped streams across sources such as:
  - location
  - motion/activity
  - pedometer/floor data
  - heart rate
  - quality/context signals where relevant
- metadata describing what activities are present and their approximate boundaries
- replay tooling for classifier iteration

### Why This Matters

Without this phase, iteration speed on the core product risk will be extremely poor.

### Exit Criteria

- developers can replay real captured data through segmentation/classification logic
- new heuristic changes can be evaluated without waiting for fresh live activity every time


## Phase 2: First Segmentation And Broad Classification

### Goal

Turn raw observations into the first plausible semantic history.

### Likely Deliverables

- first segmentation heuristics
- pause-event heuristics
- first broad classification heuristics
- low-confidence / uncertain states
- quality-state assignment

### Important Questions To Answer

- Can we keep false positives and false negatives acceptably low?
- Are segments chaotic or usable?
- Can we support indoor/treadmill-like activity at least at a basic level?

### Exit Criteria

- the system produces plausible segments from real-world test data
- uncertainty is represented instead of hidden
- obvious failures are inspectable

## Phase 3: Timeline And Segment Detail

### Goal

Make the semantic history visible and reviewable.

### Likely Deliverables

- timeline-first home
- day grouping
- segment cards
- low-confidence/review tagging
- segment detail screen
- map-forward detail for movement-heavy segments
- basic stats and heart-rate overlay

### Why This Matters

This is the first point where Blackbox starts feeling like a product rather than just a sensing experiment.

### Exit Criteria

- a user can browse a real timeline and recognize most of what happened
- a user can inspect a segment and understand why it seems right or wrong

## Phase 4: Editing And Review Loop

### Goal

Close the correction loop.

### Likely Deliverables

- reclassify
- retitle
- split
- merge
- trim
- delete
- review filters
- card-level review markers

### Why This Matters

Without correction, Blackbox remains a passive guesser.
With correction, it becomes a useful recorder.

### Exit Criteria

- users can fix common mistakes without confusion
- timeline and detail views remain coherent after edits

## Phase 5: Collections

### Goal

Add the first user-authored grouping layer above segments.

### Likely Deliverables

- create collection
- add/remove segments
- collection timeline card
- collection detail
- drill-down to underlying segments

### Why This Matters

Collections are what turn a sequence of corrected segments into meaningful outings, travel days, or stories.

### Exit Criteria

- users can group segments into meaningful higher-level units
- collections appear correctly in the timeline and detail flows

## Phase 6: Cloud Durability And Opportunistic Sync

### Goal

Add balanced local-first cloud durability without turning cloud into a runtime dependency.

### Likely Deliverables

- durable semantic sync
- adaptive sync policy
- background upload pipeline
- retry/recovery behavior
- saved export persistence path

### Why This Comes After The Core Loop

There is little value in syncing bad or unstable semantics too early.

### Exit Criteria

- local history remains correct without cloud
- cloud durability works under normal conditions
- sync failures do not corrupt or block the local app

## Phase 7: Apple Watch Participation

### Goal

Make the watch a meaningful contributor and current-activity companion.

### Likely Deliverables

- watch-native capture pipeline
- watch current-activity UI
- quick watch-side correction affordance
- watch/phone data transfer
- standalone watch recording path with later reconciliation

### Important Questions To Answer

- How much standalone recording is feasible in practice?
- How should watch and phone overlap be reconciled?
- When should workout-session-style escalation occur?

### Exit Criteria

- watch adds real value beyond passive background support on the phone
- watch-only periods still produce usable history after reconciliation

**JF Note**
I'd think data collection from the watch is right up there with collection from the iphone and should be there for the classification of segments. After all, proving the ability to pretty reliably classify activities collected passively in the background is the critycal path for Blackbox. Don't you think so?
**End JF Note**

Updated conclusion:
- Yes, watch data collection should begin earlier than full watch productization.
- The right split is:
- early watch data participation for classifier-quality development
- later watch UI, reconciliation polish, and fuller standalone behavior as a dedicated product phase

## Phase 8: Exports

### Goal

Make Blackbox shareable.

### Likely Deliverables

- export from segment
- export from collection
- selectable attributes
- saved export artifacts
- re-share path

### Why This Comes Late

Exports should reflect stable semantics, not a still-moving internal model.

### Exit Criteria

- users can create and save useful share artifacts quickly
- exports remain viewable and re-shareable

## Suggested Milestones

If the phases above feel too fine-grained, the project can also be thought of in three larger milestones.

### Milestone A: Core Passive Loop

Includes:
- foundations
- passive capture
- real-world dataset capture/replay
- first segmentation/classification
- timeline

Question answered:
- does Blackbox basically work?

### Milestone B: Trusted Recorder

Includes:
- editing
- review
- collections

Question answered:
- can the user make the record trustworthy and meaningful?

### Milestone C: Durable And Shareable

Includes:
- cloud durability/sync
- watch participation
- exports

Question answered:
- is Blackbox ready to behave like a durable personal product rather than a local prototype?

## Dependencies And Build Order Notes

### Capture Before Semantics

Do not overbuild classification before real capture data exists.

### Timeline Before Export

Do not build polished sharing before the timeline and segment model feel trustworthy.

### Editing Before Aggressive Sync

Do not invest too deeply in sync semantics before segment correction behavior is clear.

### Watch After Phone Core Loop

Do not let watch complexity block proving the phone-first core loop.

But:
- do not ignore watch architecture entirely, because later reconciliation depends on early design choices

Refined version:
- watch capture should begin early enough that the classifier can learn from realistic phone+watch data
- full watch product behavior can still come later

## Recommended First Build Focus

If I had to compress this to the most important early order, I would do:

1. foundations + local persistence
2. passive capture on iPhone
3. real-world dataset capture/replay
4. early watch data participation
5. first segmentation/classification
6. timeline + segment detail
7. editing/review

Only after that would I deepen:
- collections
- sync
- watch standalone behavior and watch UI polish
- exports

## Risks Of The Wrong Order

### If You Build Cloud Too Early

You risk syncing unstable semantics and overbuilding backend concerns before the product loop is proven.

### If You Build Sharing Too Early

You risk polishing outputs before the underlying history is trustworthy.

### If You Build Watch Too Early

You risk spending too much time on distributed-device product complexity before the core phone loop works.

Refinement:
- early watch data capture is justified
- early full watch product parity is not

### If You Ignore Editing Too Long

You risk learning from bad uncorrectable history and missing the point of the product.

## Open Phase Questions

These are the main sequencing questions still worth pressure-testing.

### 1. Watch Timing

Should meaningful watch work begin:
- only after the iPhone core loop is proven
- in parallel early, because it materially affects capture design
- as a thin early integration with standalone behavior deferred

**JF Note**
IMHO, at least data collection from the watch should start early so the data is taken into account in the implementation of the activity classifier. That being said, the Blackbox is supposed to work relaiably with just the iphone and no watch at all. So, maybe you are right about adding it at a later phase.
**End JF Note**

Updated conclusion:
- The best sequencing is likely a hybrid:
- start watch data capture early for classifier-quality reasons
- keep the phone-only path as a first-class success path
- defer richer watch product behavior until after the core phone loop is proven

### 2. Sync Timing

Should cloud durability begin:
- only after timeline/editing feel stable
- earlier, because losing data during development is too costly

**JF Note**
During development, I am more concerned with having sufficient raw data to work with and keep iterating over when seating in my comfy chair and not roaming around on foot or by car.
**End JF Note**

Updated conclusion:
- Development-time data retention and replay are early priorities even if production retention is more selective.

### 3. Export Timing

Should exports come:
- after collections
- earlier, directly from segments, to validate shareability sooner

**JF Note**
After
**End JF Note**

Updated conclusion:
- Exports should stay after collections.

### 4. Collection Timing

Should collections wait until editing is solid, or should they appear earlier because they are central to meaning?

**JF Note**
After
**End JF Note**

Updated conclusion:
- Collections should stay after editing is solid.
