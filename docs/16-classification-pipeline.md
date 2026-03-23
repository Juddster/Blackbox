# Blackbox Classification Pipeline

This document describes the intended processing pipeline that turns captured device data into semantic Blackbox history.

It is still a design document, not an implementation of algorithms.

Its purpose is to define:
- the stages of processing
- the responsibilities of each stage
- what inputs and outputs each stage should use
- where uncertainty and review are introduced
- how replay-based iteration should fit into the same model

## Scope Basis

This document assumes:
- [09-v1-requirements-spec.md](/Users/judd/DevProjects/Blackbox/docs/09-v1-requirements-spec.md)
- [10-domain-model-draft.md](/Users/judd/DevProjects/Blackbox/docs/10-domain-model-draft.md)
- [11-apple-device-capabilities.md](/Users/judd/DevProjects/Blackbox/docs/11-apple-device-capabilities.md)
- [12-implementation-phases.md](/Users/judd/DevProjects/Blackbox/docs/12-implementation-phases.md)
- [14-sync-storage-strategy.md](/Users/judd/DevProjects/Blackbox/docs/14-sync-storage-strategy.md)

## Pipeline Goal

The pipeline should transform:
- noisy multi-stream observations

Into:
- plausible segments
- conservative classifications
- meaningful summaries
- explicit quality/confidence state
- reviewable issues when needed

The core priority is:
- low false positives
- low false negatives

More than fine-grained subtype sophistication.

## Inputs

The pipeline may consume any combination of:
- iPhone location
- watch location when available
- motion/activity signals
- pedometer/floor signals
- heart rate
- device state
- connectivity state
- support evidence derived from recent observations
- user hints or corrections

## Outputs

The pipeline should produce:
- SegmentRecord
- SegmentInterpretationRecord
- SegmentSummaryRecord
- PauseEventRecord
- QualityRecord
- ReviewItemRecord where needed

## Pipeline Stages

## Stage 0: Observation Ingestion

### Purpose

Normalize incoming streams from different sources into a common observation layer.

### Responsibilities

- timestamp normalization
- source tagging
- device tagging
- payload normalization
- persistence into live observation storage

### Notes

This stage should not try to assign semantic meaning yet.

## Stage 1: Observation Quality Screening

### Purpose

Identify observations that are clearly unusable, suspicious, or degraded before they distort later stages.

### Responsibilities

- reject or flag impossible values
- identify location anomalies
- flag missing or sparse data conditions
- annotate source reliability hints

### Examples

- impossible jumps in position
- clearly implausible speed
- degraded route continuity
- watch/phone disagreement worth flagging

### Output

- cleaned observation stream
- quality hints for downstream stages

## Stage 2: Windowing And Feature Extraction

### Purpose

Turn raw observation streams into short rolling windows and derived features that later heuristics can actually use.

### Responsibilities

- define rolling or event-driven windows
- derive motion features
- derive pace/speed features
- derive route-shape features
- derive stop/resume features
- derive heart-rate features
- derive indoor/non-location movement clues
- derive stair/climb clues where available

### Notes

This is where the pipeline stops thinking in raw sensor terms and starts thinking in activity signals.

## Stage 3: Candidate Activity-State Estimation

### Purpose

Estimate what broad activity state is likely happening in each local time window.

### Target broad states

- stationary
- walking
- running
- cycling
- hiking candidate
- vehicle
- flight
- water activity
- unknown / mixed / uncertain

### Responsibilities

- score candidate states
- preserve ambiguity where appropriate
- avoid premature narrow classification

### Notes

This stage is local and provisional.
It does not yet decide final segment boundaries.

## Stage 4: Boundary Detection And Segmentation

### Purpose

Convert changing local activity-state estimates into meaningful segments.

### Responsibilities

- detect activity starts
- detect activity ends
- detect transitions
- avoid excessive fragmentation
- identify candidate pauses within a segment

### Key Principle

Boundary detection is a different problem from classification.

The pipeline should not assume:
- every local state change means a segment boundary
- every low-motion interval means a new segment

### Important Cases

- traffic stop during vehicle travel
- coffee break during hiking-like movement
- alternating run/walk patterns
- indoor workout without route change

## Stage 5: Segment-Level Classification

### Purpose

Assign a conservative visible class to the segment as a whole.

### Responsibilities

- aggregate evidence across the segment
- decide broad visible class
- fall back to uncertain or broader labels when needed
- optionally attach narrower user-facing suggestions later

### v1 Visible Classes

- stationary
- walking
- running
- cycling
- hiking when confidence is reasonably strong
- vehicle
- flight
- water activity
- unknown / mixed / uncertain

### Important Principle

If the segment is real but the label is uncertain, preserve the segment and lower the label confidence.

## Stage 6: Pause Detection

### Purpose

Identify meaningful interruptions within a segment without over-splitting the segment.

### Responsibilities

- detect likely pause intervals
- evaluate them in context of the surrounding activity
- distinguish between:
  - real segment transition
  - pause within same activity
  - ambiguous case needing caution

### Important Principle

Pause detection is contextual.
It should consider:
- duration
- movement radius
- exertion changes
- relationship to the surrounding activity

## Stage 7: Quality Assessment

### Purpose

Assign trustworthiness and suspiciousness state to the segment or its sub-intervals.

### Responsibilities

- mark degraded data
- mark implausible intervals
- mark suspicious intervals
- auto-trim obviously bad data where confidence is high

### Output

- quality state for the segment
- sub-interval quality markers where needed
- possible review items

## Stage 8: Summary Derivation

### Purpose

Produce the current semantic summary used by the UI and exports.

### Responsibilities

- compute duration
- compute distance
- compute elevation gain
- compute route summary
- compute speed summary
- compute heart-rate summary
- compute pause count
- compute quality summary

## Stage 9: Review Generation

### Purpose

Create explicit review items when uncertainty or suspiciousness crosses a threshold.

### Responsibilities

- identify low-confidence segments
- identify suspicious intervals
- identify ambiguous classifications
- create segment-level or sub-interval review items

### Important Principle

Not every low-confidence signal should become a user-facing burden.
The thresholds should be tuned so that review remains useful rather than noisy.

## Stage 10: Settlement And Compaction

### Purpose

Move a segment from recent/unsettled state to settled durable history.

### Responsibilities

- determine when a segment has settled
- compact or discard no-longer-useful support baggage
- retain durable semantic history
- preserve corrections and saved exports

## Live Pipeline vs Replay Pipeline

The same conceptual stages should support both:
- live processing
- replay-based classifier iteration

### Live Mode

Priorities:
- timeliness
- battery efficiency
- graceful degradation

### Replay Mode

Priorities:
- repeatability
- comparison across heuristic versions
- tuning false positives / false negatives

### Important Principle

Replay should not be a separate conceptual algorithm.
It should exercise the same pipeline with different runtime assumptions.

## Classification Heuristic Priorities

The heuristic order of importance should be:

### 1. Is there a real segment here?

First determine whether a meaningful activity happened at all.

### 2. Where are its boundaries?

Second determine its start, stop, pauses, and transitions.

### 3. What broad class is it?

Only after the first two are reasonably strong should the classifier commit to broad labels.

### 4. Is narrower interpretation worth suggesting?

This is lowest priority for v1.

## Special Cases The Pipeline Must Respect

### Indoor / Treadmill Activity

The pipeline must support movement without meaningful route change.

Key sources:
- motion/activity
- pedometer/floors
- watch signals
- heart rate

### Stair Activity

The pipeline should leave room for stair-related inference or later manual labeling.

### Flight

The pipeline should infer flight conservatively from composite evidence, not assume continuous in-air GPS.

### Water Activity

The pipeline should prefer broad `water activity` over overconfident subtype guessing.

### Phone-Only Mode

The pipeline must remain useful even when no watch is present.

### Watch-Enhanced Mode

When watch data is present, the pipeline should exploit it without becoming dependent on it.

**JF Note**
- Watch only Mode
**End JF Note**

### Watch-Only Mode

The pipeline should remain viable when:
- the watch is actively collecting
- the phone is not nearby
- reconciliation will happen later

This is different from watch-enhanced mode and should be treated as its own operational case.


## User Corrections In The Pipeline

**JF Note**
- User may indicate activity type at any point during the activity as well as post. For example, they glance at the app (or watch) during the activity and see that blackbox thinks they are walking when, in fact, the user considers this a running session. User's clasification always wins. 
**End JF Note**

Updated conclusion:
- User classification override should be treated as authoritative.
- The user must be able to correct activity type:
- during the activity
- after the activity
- from phone or watch when applicable
- This correction should immediately become the effective interpretation used by the semantic history.

User edits do not just affect the UI.
They affect the semantic record.

### Required Behavior

- reclassification updates the effective interpretation
- split/merge/trim update the effective segment set
- summaries must be recomputed after edits
- review state may be resolved by user action

### Important Limitation

v1 should still favor current effective state over rich historical version trees.

## Metrics For Pipeline Evaluation

The pipeline should eventually be evaluated on:
- false positives
- false negatives
- segment boundary plausibility
- review burden
- rate of manual correction needed
- ability to reconstruct important real activities

## Open Pipeline Questions

### 1. Boundary Bias

When uncertain, should the pipeline tend to:
- over-split and let the user merge
- under-split and let the user split
- vary by activity type

**JF Note**
I can't say at this point. It is a matter of fine tunning. Niether over nor under is good.
**End JF Note**

Updated conclusion:
- Boundary bias should remain an empirical tuning question.
- The right answer may vary by activity family and by failure mode.
- The important design stance is:
- neither systematic over-splitting nor systematic under-splitting is desirable
- the tuning process should optimize for practical correction burden

### 2. Confidence Thresholds

Should the thresholds for:
- visible class confidence
- pause detection
- review generation

be globally simple at first, or tuned separately by activity family?

**JF Note**
Again, we'll have to fine tune as we go. Initially, as the sole user and developer, I am willing to tolerate having to make much more corrections than I anticipate a casual end user would. Or, maybe I am missing the question here?
**End JF Note**

Updated conclusion:
- That is the right interpretation.
- The question is about whether early thresholds should be globally simple or already specialized by activity family.
- For v1 development, simpler initial thresholds are probably acceptable because you are willing to tolerate more correction while tuning.

### 3. Watch Escalation Trigger

At what confidence should the system escalate into stronger watch-side capture or workout-session-style behavior?

**JF Note**
Please clarify the question.
**End JF Note**

Clarification:
- "watch escalation trigger" means:
- at what point the system should switch from ordinary passive watch participation into a stronger watch-side capture mode, such as a workout-session-style mode, because it believes a workout-like activity is probably underway

Updated conclusion:
- This should remain open until practical testing shows when escalation improves capture/classification more than it harms battery or causes false triggers.
