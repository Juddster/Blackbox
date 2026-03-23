# Blackbox V1 Requirements Spec

This document turns the approved v1 scope into feature-by-feature product requirements.

It is still product/technical specification, not an implementation task list.

Its purpose is to define:
- what each v1 feature must do
- what it does not need to do
- what edge cases matter
- what "good enough" means for acceptance

## Scope Basis

This document assumes:
- the current synthesis in [06-synthesis.md](/Users/judd/DevProjects/Blackbox/docs/brainstorming/06-synthesis.md)
- the architecture direction in [07-architecture-overview.md](/Users/judd/DevProjects/Blackbox/docs/07-architecture-overview.md)
- the approved v1 scope in [08-v1-scope-spec.md](/Users/judd/DevProjects/Blackbox/docs/08-v1-scope-spec.md)
- sync/storage `Option B: Balanced Local-First Cloud`

## V1 Thesis

Blackbox v1 should replace unreliable manual start/stop activity tracking with a passive, local-first timeline of meaningful movement segments that the user can trust, correct, organize, and share.

## Primary v1 Quality Objective

The primary v1 quality objective is:
- low false positives
- low false negatives

In practical terms:
- meaningful real activities should not be missed too often
- activities that never really happened should not appear too often

This priority is more important than deep subtype accuracy.

## Feature Areas

## 1. Passive Capture

### Goal

Capture enough signal in the background to reconstruct meaningful activity segments without requiring manual session start/stop.

### Required Behavior

- The iPhone app must collect background observations relevant to movement/activity reconstruction.
- The Apple Watch app must contribute watch-native observations when available.
- The system must continue collecting locally even when cloud sync is unavailable.
- The system must tolerate intermittent signal quality and temporary sensor loss.

### Non-Goals

- Capturing every possible sensor at maximum fidelity all the time.
- Acting as a generic raw sensor logger for forensic export.

### Edge Cases

- Phone present, watch absent.
- Watch present, phone absent.
- Both present with overlapping observations.
- Device enters Low Power Mode.
- Connectivity becomes poor or unavailable.

### Acceptance Criteria

- The system usually captures enough data to reconstruct ordinary real-world movement/activity periods.
- Temporary signal loss does not cause total loss of the day’s history.
- Capture continues locally without requiring immediate cloud availability.

## 2. Segmentation

### Goal

Turn captured observations into plausible activity segments and pause events.

### Required Behavior

- The system must identify segment start and end boundaries.
- The system must support pauses within segments.
- The system must separate obvious activity transitions into different segments.
- The system must support uncertain or mixed segments when boundaries or class are ambiguous.

### Non-Goals

- Perfect segmentation under all conditions.
- Fine-grained decomposition of every micro-transition.

### Edge Cases

- Red-light or traffic stops during vehicle travel.
- Rest breaks during walking/running/hiking-like activity.
- Tunnel transit or GPS degradation.
- Short transitions between related activities.

### Acceptance Criteria

- Segment boundaries are not obviously chaotic most of the time.
- Short pauses do not unnecessarily fragment ordinary activities.
- Major transitions are usually represented as different segments.

## 3. Classification

### Goal

Assign a conservative visible activity class to each segment.

### Required Behavior

- The system must support these visible v1 classes:
  - stationary
  - walking
  - running
  - cycling
  - hiking when confidence is reasonably strong
  - vehicle
  - flight
  - water activity
  - unknown / mixed / uncertain
- The system must fall back to a broader or more uncertain label when confidence is not sufficient.
- The system must support manual reclassification by the user.
- The system must allow user-selected finer labels even when they are not part of automatic v1 visible inference.

**JF Note**
It occured to me that walking and running on a treadmill or indors don't come with location chnage. It is very important that we recognize such activity from other signals. As a fallback, if we are not able to infer that, the user should be able to add such activities manually or, in the future, import them from other soureswes.
**End JF Note**

Updated conclusion:
- Classification must not assume meaningful movement always implies location change.
- Indoor or treadmill-like walking/running should be treated as real target cases for non-location-driven inference.
- If the system cannot infer such activity reliably, the user must still be able to add or correct it manually.

### Non-Goals

- Reliable automatic inference of transport subtypes such as train, bus, motorcycle, or driving.
- Reliable automatic inference of water subtypes such as swimming, rowing, sailing, or speed boat.

### Edge Cases

- Walking vs hiking.
- Hiking vs running on trails.
- Indoor walking or running with little or no location change.
- Vehicle travel with degraded GPS.
- Flight with sparse in-air location coverage.
- Water activity without reliable subtype evidence.

### Acceptance Criteria

- The classifier is conservative rather than overconfident.
- Obvious broad classes are usually plausible.
- Ambiguous segments are labeled honestly rather than forced into narrow classes.

## 4. Quality And Ambiguity Handling

### Goal

Represent uncertainty and data quality problems explicitly.

### Required Behavior

- The system must assign quality state when data is degraded, implausible, or suspicious.
- The system must mark low-confidence or needs-review segments.
- The system must auto-trim obviously bad portions when confidence in the trim is high.
- The system must surface less-obvious issues for later review.

### Non-Goals

- Perfect automatic repair of all bad data.
- Real-time interruption for every questionable event.

### Edge Cases

- GPS jamming.
- Tunnel transit.
- Urban canyon drift.
- Conflicting watch/phone signals.

### Acceptance Criteria

- Bad data does not silently poison the timeline too often.
- Uncertain history is discoverable and fixable.
- The user can tell which items may need review.

## 5. Timeline

### Goal

Provide a timeline-first experience that feels like a useful semantic record of the user’s history.

### Required Behavior

- The home surface must be a timeline-first scrolling card feed.
- The timeline must group content by day.
- The timeline must display segments, collections, and important overlays/events.
- The timeline must visually tag low-confidence and needs-review items.
- The timeline must support filtering by:
  - activity type
  - review state
  - confidence/quality-related state
- The timeline must support search by:
  - title
  - location/area

### Non-Goals

- A raw sensor feed.
- A map-first home surface in v1.

### Edge Cases

- Very noisy days with many small segments.
- Days containing collections that subsume multiple segments.
- Segments with uncertain labels.

### Acceptance Criteria

- A user can scan the timeline and recognize most of what happened.
- The timeline remains readable when review/uncertainty items exist.
- Filters make it practical to focus on activities or issues of interest.

## 6. Segment Detail

### Goal

Provide enough context for the user to understand and correct a segment.

### Required Behavior

- Segment detail must show:
  - map/route when relevant
  - visible class
  - summary stats
  - confidence/quality context when relevant
  - pause information when available
  - heart-rate overlay when meaningful and available
- Movement-heavy segments must be map-forward.

### Non-Goals

- Raw-sample forensic inspection in the main v1 UI.

### Edge Cases

- Segments with poor GPS quality.
- Segments with no meaningful map.
- Segments reclassified by the user after the fact.

### Acceptance Criteria

- A user can usually decide from the detail view whether the segment is broadly correct.
- Important quality or confidence issues are visible without overwhelming the screen.

## 7. Editing

### Goal

Let the user correct meaning without requiring raw-point editing.

### Required Behavior

- The user must be able to:
  - retitle a segment
  - reclassify a segment
  - split a segment
  - merge consecutive segments
  - trim a segment
  - delete a segment
  - add notes/tags
  - add a segment to a collection
- Reclassification must support user-chosen labels beyond the automatic visible inference set.
- Segment summaries must remain coherent after edits.

**JF Note**
User should be able to merge two or more consecutive segments into one. For example, the clasifier may produce a few alternating running and walking segment. The user may just want to consider those as one running activity. Or a few alternating traveling and walking segments that the user want to merge into one public transportation segment.

This is different than a collection. In the user's mind, a collection is a conjunction of a few distinct activities. merging segments into one is more like fixing a missed auto-classification by the system.
**End JF Note**

Updated conclusion:
- Merge is a first-class editing operation in v1.
- It is conceptually different from collections:
- merging repairs over-fragmented or mis-segmented history into one semantic activity
- collections organize multiple still-distinct activities into a larger meaningful unit

### Non-Goals

- Point-by-point route manipulation.
- Full audit-history UI in v1.

### Edge Cases

- Splitting a segment into differently labeled child segments.
- Merging alternating small segments into one corrected activity.
- Trimming a suspicious interval out of a segment.
- Reclassifying a broad segment into a narrower user-selected label.

### Acceptance Criteria

- Common fixes can be performed without confusion.
- Edits feel stable and are reflected correctly in the timeline and detail views.

## 8. Collections

### Goal

Allow the user to group segments into higher-level meaningful units.

### Required Behavior

- The user must be able to create collections.
- Collections must appear as first-class cards on the timeline.
- Collections must support:
  - multiple segments
  - renaming
  - add/remove segment
  - collection detail view
- Collection detail must allow drill-down into contained segments.
- When a collection is present, its child segments may be hidden from the top-level timeline by default.

### Lower-Priority Behavior

- Notes/media inside collections if feasible without destabilizing v1.

### Non-Goals

- Rich nested collection hierarchies in v1.

### Edge Cases

- A collection spanning mixed activity types.
- A collection created after the segments already exist.
- A collection used primarily as a share/export source.

### Acceptance Criteria

- Collections feel like meaningful user-authored groupings, not just tags.
- A user can use collections to represent outings, travel days, or multi-part activities.

## 9. Review

### Goal

Make uncertain or suspicious history easy to find and resolve.

### Required Behavior

- Review must primarily be handled through timeline filters and card-level markers.
- Segments needing review must be identifiable from the timeline.
- The user must be able to filter to review-oriented views such as:
  - needs review
  - low confidence
  - suspicious quality

### Non-Goals

- A complex dedicated review workflow if the timeline-based model is sufficient.

### Acceptance Criteria

- A user can quickly locate the main items that need attention.
- Review handling does not dominate normal browsing of the timeline.

## 10. Exports

### Goal

Let the user quickly share segments or collections as curated artifacts.

### Required Behavior

- The user must be able to export from a segment or a collection.
- Export must feel like a quick-share flow.
- The user must be able to select which attributes are included in the export.
- Saved exports must be treated as first-class artifacts in v1.

### Non-Goals

- Deep destination-specific customization.
- A heavy story-builder editor.
- Web-link sharing as the primary sharing model.

### Edge Cases

- Sharing a collection with mixed activities.
- Sharing only selected attributes for privacy/relevance reasons.
- Re-sharing a previously saved export.

### Acceptance Criteria

- A user can quickly produce a shareable artifact without deep manual composition.
- Saved exports are stable and accessible later.

## 11. Sync And Cloud

### Goal

Provide durable cloud-backed storage without making cloud round-trips required for normal operation.

### Required Behavior

- The app must operate correctly when temporarily offline.
- Durable semantic history must sync to cloud opportunistically.
- In-progress activities may upload adaptively when conditions are good.
- Sync behavior must consider:
  - battery state
  - Low Power Mode
  - charging state
  - network quality
  - Wi-Fi/cellular/roaming-related policy where detectable
- v1 storage/sync design must avoid painting future multi-user support into a corner.

### Non-Goals

- Multi-user cloud product delivery in v1.
- Heavy server-side analytics.
- Web consumption surfaces.

### Acceptance Criteria

- Sync failures do not break local history.
- Durable history reaches cloud storage under normal conditions.
- Long important activities are not left entirely unsynced when good opportunities to sync exist.

## 12. Health Overlay

### Goal

Use lightweight health data to enrich segment understanding.

### Required Behavior

- Heart rate is the minimum required v1 health overlay.
- Heart-rate data must appear where meaningful and available.
- Health overlay must support both:
  - segment understanding
  - lightweight historical context

### Non-Goals

- Full longitudinal health dashboard product in v1.
- Broad multi-metric health interpretation in v1.

### Acceptance Criteria

- Heart-rate information usefully enriches relevant segment detail.
- Health overlay does not turn the product into a generic health app.

## 13. Apple Watch Behavior

### Goal

Make the watch both a useful sensor source and a meaningful current-activity companion.

### Required Behavior

- The watch must contribute watch-native observations.
- The watch must have activity-aware current UI.
- The watch must allow the user to correct the current inferred activity quickly.
- The watch should provide meaningful standalone recording usefulness.
- The watch should support extended recording when the phone is not nearby, ideally up to roughly a full day if feasible.

### Non-Goals

- Full feature parity with the phone app in v1.

### Acceptance Criteria

- The watch adds meaningful value beyond passive background sensing alone.
- The product remains useful during periods when the watch is recording without the phone nearby.

## 14. Settings And Policies

### Goal

Give the user control over the app’s passive behavior without making configuration burdensome.

### Required Behavior

- The user must be able to configure policy behavior related to:
  - battery usage
  - Low Power Mode
  - sync aggressiveness
  - review/notification behavior
- The user must be able to override policy when needed.

### Non-Goals

- Exposing every internal tuning knob in v1.

### Acceptance Criteria

- A user can understand and change the major behavior policies without confusion.
- Policy settings feel like practical control, not engineering clutter.

## Explicit v1 Non-Requirements

These are intentionally not required for v1:
- web app
- Android app
- Garmin or third-party wearable integrations
- sleep as a first-class segment type
- deep transport subtype inference
- deep water subtype inference
- broad health-history dashboards
- public/social feed functionality
- automatic reinterpretation of old settled history

## Acceptance Summary

v1 should be considered successful if:
- passive capture and segmentation are reliable enough to reduce manual tracking burden
- the timeline usually feels plausible
- false positives and false negatives stay low enough to maintain trust
- the user can correct and organize history without friction
- cloud durability works without becoming a runtime dependency
- exports and collections are useful enough to justify continued use

## Next Documents

The most natural next documents after this one are:
- `10-domain-model-draft.md`
- `11-apple-device-capabilities.md`
- `12-implementation-phases.md`
