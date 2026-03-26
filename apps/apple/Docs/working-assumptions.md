# Blackbox Apple App Working Assumptions

This brief condenses the planning docs into implementation guidance for the Apple app.

## Product Goal

Blackbox v1 is a local-first, cloud-backed passive activity journal.

The core loop is:
- capture passively
- segment captured history into meaningful activities
- classify conservatively
- surface uncertainty honestly
- let the user correct the result
- preserve the corrected semantic history

## Primary Quality Target

The most important v1 quality target is:
- low false positives
- low false negatives

This matters more than deep subtype accuracy.

In practical terms:
- do not miss real meaningful activities too often
- do not invent activities that never happened
- prefer a broad or uncertain label over a confidently wrong narrow label

## Platform Shape

- iPhone is the primary long-lived product surface.
- Apple Watch is a strong capture companion and current-activity surface.
- Watch-only capture is a real operating mode and must reconcile later.
- Cloud is part of the product architecture, but runtime correctness must not depend on cloud availability.

## v1 Visible Activity Classes

The visible classes currently in scope are:
- stationary
- walking
- running
- cycling
- hiking when confidence is strong enough
- vehicle
- flight
- water activity
- unknown / mixed / uncertain

Notes:
- Walking is the safer fallback when hiking evidence is weak.
- Transport and water subtypes may exist as user-selected labels later, but should not drive automatic v1 overreach.

## Important Classification Constraints

- Segmentation and classification are different problems and should remain separate in code.
- If a segment is real but the label is uncertain, preserve the segment and lower confidence.
- Indoor and treadmill-like activity must be treated as real target cases even when location change is weak.
- Watch data should improve results without becoming a hard dependency.

## User Correction Rules

- User classification override is authoritative.
- The user must be able to correct activity type during or after an activity.
- User edits affect the semantic record, not just the current UI.
- Split, merge, trim, delete, and reclassify must leave the timeline and summaries internally consistent.

## Data Model Direction

Keep a strong separation between:
- raw observations and short-term support data
- durable semantic history

The durable history should center on:
- segments
- current interpretation
- current summary
- pause events
- quality and review state
- collections
- exports

For v1, favor current effective state over elaborate history/version trees.

## Storage And Sync Direction

- Dense live observations are primarily local and mostly temporary.
- Durable semantic history is synced.
- Selected support evidence may sync when justified, but should not become permanent baggage by default.
- Segments should conceptually move through active, unsettled, and settled states.
- Once a segment is settled, support baggage should usually be compacted or discarded.

## Timeline And UX Direction

- The home surface should be timeline-first, not map-first.
- Timeline readability matters more than exposing raw sensor detail.
- Low-confidence and needs-review state should be visible in the main flow.
- Timeline review should likely be filter-driven before inventing a heavy separate review workflow.

## Implementation Priorities

Near-term implementation should optimize for proving this loop early:
1. passive capture
2. observation persistence
3. first segmentation
4. conservative classification
5. timeline rendering
6. correction flow

An early replay workflow for real multi-stream captured data is part of the critical path for classifier tuning.

## Non-Goals For Early Apple App Work

Avoid overbuilding these too early:
- deep subtype inference
- heavy schema versioning
- rich historical edit trees
- cloud-coupled capture behavior
- raw-sensor-forensics UI
- complex live-sharing architecture

## Open Engineering Reminders

These are still empirical questions and should be validated with real data:
- battery cost of the capture mix
- indoor activity reliability
- watch-only capture quality
- practical boundary-tuning bias
- when stronger watch-side workout-style capture is worth escalating into
