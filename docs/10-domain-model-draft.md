# Blackbox Domain Model Draft

This document turns the conceptual model into a more concrete domain draft for v1.

It is still not a database schema or API contract.

Its purpose is to define:
- the main domain entities
- the meaning of each entity
- the most important relationships
- which entities are durable versus temporary
- what must remain true when the user edits history

## Scope Basis

This draft assumes:
- [06-synthesis.md](/Users/judd/DevProjects/Blackbox/docs/brainstorming/06-synthesis.md)
- [07-architecture-overview.md](/Users/judd/DevProjects/Blackbox/docs/07-architecture-overview.md)
- [08-v1-scope-spec.md](/Users/judd/DevProjects/Blackbox/docs/08-v1-scope-spec.md)
- [09-v1-requirements-spec.md](/Users/judd/DevProjects/Blackbox/docs/09-v1-requirements-spec.md)

## Modeling Principles

The domain model should preserve these principles:
- observed data is not the same as inferred meaning
- inferred meaning is not the same as user-corrected meaning
- grouping is not the same as correction
- sharing is not the same as storage
- temporary support data is not the same as durable semantic history

## Core Entity Set

The recommended v1 domain entities are:
- Observation
- Segment
- SegmentInterpretation
- SegmentSummary
- PauseEvent
- QualityAssessment
- Annotation
- EditRecord
- ReviewItem
- Collection
- ExportArtifact

## 1. Observation

### Purpose

Represents a captured input datum or support signal.

### Examples

- location fix
- motion reading
- step or cadence-related reading
- speed/elevation sample
- heart rate sample
- device state sample
- connectivity state sample

### Characteristics

- timestamped
- source-specific
- usually high-volume
- often temporary
- generally not user-facing directly

### Durability

- some observations are transient
- some derived support evidence may be retained longer

### Notes

Observations are not part of the main semantic history surface. They support inference, editing consequences, and summary derivation.

## 2. Segment

### Purpose

Represents a continuous or near-continuous meaningful activity period in history.

### Examples

- walking segment
- running segment
- cycling segment
- stair-climbing segment
- vehicle segment
- water activity segment
- flight segment
- uncertain segment

**JF Note**
Another activity type is stair climbing. A hike or walk can include a short stair climb but stair climbing could be a workout activity of its own. Whether real stairs or on a stairmaster.
**End JF Note**

Updated conclusion:
- Stair climbing is worth keeping in mind as a user-meaningful activity label, especially as a manual or later refinement label even if automatic v1 inference stays conservative.

### Core Fields

- stable segment id
- start time
- end time
- source/origin metadata
- current lifecycle state

### Important Property

The Segment is the core semantic unit on the timeline.

It should remain stable enough that:
- interpretations can change
- summaries can be recomputed
- edits can be recorded

Without requiring the segment itself to be conceptually replaced every time.

## 3. SegmentInterpretation

### Purpose

Represents the current meaning assigned to a segment.

### Why It Exists Separately

Because:
- the system may initially infer one meaning
- the user may later correct that meaning
- the system may attach confidence and ambiguity states

Without changing the existence of the segment itself.

### Suggested Contents

- visible class
- optional narrower user-selected class
- confidence
- ambiguity/mixed-state marker
- whether user review is needed
- origin of interpretation:
  - system
  - user
  - mixed/system-assisted

### Important Distinction

The visible class may remain broad while the user-selected class may be narrower.

Example:
- visible v1 system class: `vehicle`
- user-selected finer meaning: `public transportation`

**JF Note**
. Does the SegmentInterpretation record stick around permanently? It seems to me that once things settle, all that matters from the record is the segment clasification (borad or narrow). 
. For narrower options we could have 'public transportation' as well as bus, train, cab, etc. It doesn't neccessarily make a difference to the system. But the user might want to be more specific. So we should have those options in the list.
**End JF Note**

Updated conclusion:
- The model does not need rich historical interpretation versioning in v1.
- A simpler and better v1 approach is:
- keep the current effective interpretation on the segment
- allow it to be system-assigned or user-corrected
- preserve only as much supporting metadata as needed for confidence/review and edit correctness
- User-selectable narrower labels should remain available even when they do not materially affect system behavior.


## 4. SegmentSummary

### Purpose

Represents durable computed facts about a segment.

### Examples

- duration
- distance
- route geometry summary
- elevation gain
- average speed
- max speed
- pause count
- heart-rate summary
- quality-related summary fields

### Notes

This is what most UI cards and export surfaces should read from.

## 5. PauseEvent

### Purpose

Represents a stop or interruption inside a segment that should not necessarily split it.

### Examples

- stoplight during travel
- rest break during an outdoor activity
- temporary pause in a longer continuous effort

**JF Note**
This is probably not the right place to dicsuss it, so please update the right doc but, what is considered a stop. Let's say I'm hiking and I stopped for a coffee break. I'm not just sitting in one place. from time to time I may walk around the break area for this and that. So, even a stop is not a clear cut stop. It has to be evaluated in the context of the activity before and after (length, distance, excertion level, and perhaps some other indicators too of both stop and bracketing activities).
**End JF Note**

Updated conclusion:
- Pause/stop detection is context-sensitive rather than binary.
- A pause should be interpreted in relation to the surrounding segment, not just by zero movement.
- This is primarily a segmentation/heuristics concern, but the domain model should allow pause events to represent approximate interruptions without implying a perfectly clean stop state.


### Core Fields

- parent segment id
- start time
- end time
- optional inferred reason/type

## 6. QualityAssessment

### Purpose

Represents the system’s view of data trustworthiness for a segment or sub-interval.

### Examples

- trusted
- degraded
- implausible
- auto-trimmed
- suspicious

### Notes

This should remain conceptually distinct from activity classification.

A segment can be:
- confidently `vehicle`
- but still contain degraded or suspicious route quality

## 7. Annotation

### Purpose

Represents user-authored meaning attached to a segment or collection.

### Examples

- title
- notes
- tags
- photos/media
- freeform comments

**JF Note**
- Photos
**End JF Note**

Updated conclusion:
- Media attachments belong naturally with annotations, even if v1 only supports them in a limited way.


### Notes

Annotations enrich the history without redefining the underlying observations.

## 8. EditRecord

### Purpose

Represents a user action that changes how history is represented.

### Why It Matters

Edits are part of the durable semantic history, even if v1 does not expose a full audit log UI.

### Supported Edit Types For v1

- reclassify
- retitle
- split
- merge
- trim
- delete
- add-to-collection
- remove-from-collection

### Critical Distinction

Merge and Collection are not the same.

- Merge means: these should really be one semantic segment.
- Collection means: these remain distinct segments but belong together in a higher-level grouping.

**JF Note**
To be honest, I don't see the purpose of the edit record (except for maybe a transient item that makes implementation more convenient ot resilient or whatever). Why not just apply the edit to the segment itself and call it a day?
**End JF Note**

Updated conclusion:
- This is a fair pushback.
- For v1, a lightweight edit-history model is probably enough, and a heavy standalone edit-record system would likely be overengineering.
- The practical compromise is:
- apply edits directly to the current segment/collection state
- keep only minimal structured metadata when needed for resilience, sync correctness, or internal traceability
- do not treat edit history as a prominent rich domain surface in v1


## 9. ReviewItem

### Purpose

Represents something the system wants surfaced for later human attention.

### Examples

- low-confidence segment
- suspicious GPS interval
- possible bad route
- ambiguous classification

### Notes

Even if review is mostly shown via timeline filters and tags, it still helps to model reviewable issues explicitly.

**JF Note**
I assume this record goes away after the item has been reviewed?
**End JF Note**

Updated conclusion:
- ReviewItem should usually be treated as active workflow state, not permanent history.
- Once resolved, it can be removed or compacted into minimal state rather than kept as a rich durable record forever.


## 10. Collection

### Purpose

Represents a user-meaningful grouping of distinct segments.

### Examples

- Saturday ride
- travel day
- triathlon
- weekend outing

### Core Behaviors

- may contain multiple segments
- appears on the timeline
- has its own title and metadata
- has its own summary view
- allows drill-down into constituent segments

### v1 Scope Note

Collections should be in the domain from day one.

Notes/media inside collections are useful but lower priority than the basic grouping semantics.

## 11. ExportArtifact

### Purpose

Represents a saved export generated from a segment or collection.

### Examples

- route card
- shareable stat summary
- timeline-style story artifact

### Notes

Exports are:
- derived from history
- selectable in content
- durable when saved

They are not the same thing as cloud sync or backup.

## Relationship Model

At a high level:

- Observations support Segments.
- Segments have one current SegmentInterpretation.
- Segments have one or more derived SegmentSummary states over time, with one current effective summary.
- Segments may have PauseEvents.
- Segments may have QualityAssessments.
- Segments may have Annotations.
- Segments may generate ReviewItems.
- Collections group Segments.
- Collections may have Annotations.
- Exports derive from either Segments or Collections.

Updated relationship guidance:
- Edit metadata, if kept at all in v1, should be lightweight and subordinate to the current segment/collection state rather than modeled as a heavy independent object.

## Entity Lifetimes

### Mostly Temporary

- raw Observations

### Potentially Retained Longer

- selected support evidence derived from Observations

### Durable

- Segments
- current SegmentInterpretation state
- SegmentSummary
- PauseEvent
- QualityAssessment
- Annotation
- minimal edit metadata when needed
- active ReviewItem state or compact review markers
- Collection
- ExportArtifact

## Required Invariants

The domain should preserve these invariants:

### 1. A Segment Cannot Be Both Merged And Still Independently Present Without Explicit Rule

If segments are merged into one corrected segment, the resulting representation must be internally consistent.

### 2. Collection Membership Does Not Change Segment Identity

Putting segments into a collection does not turn them into one activity.

### 3. Reclassification Does Not Require Raw Point Editing

A user can change the meaning of a segment without modifying the underlying observation stream.

### 4. Low Confidence Does Not Invalidate Existence

A segment may be uncertain in label while still being a real timeline object.

### 5. Export Does Not Mutate History

Creating or saving an export should not change the underlying segment or collection semantics.

## Suggested v1 Modeling Shortcuts

To avoid overengineering:

- keep one current SegmentInterpretation rather than full interpretation version trees
- keep one current SegmentSummary rather than multiple historical summary snapshots unless needed by edits
- keep ReviewItem simple
- keep Collection hierarchy flat in v1
- treat notes/media in collections as optional extensions
- prefer direct current-state mutation plus minimal metadata over rich edit-history modeling

## Open Modeling Questions

These are the main domain questions still worth pressure-testing:

### 1. Segment Identity After Split/Merge

When a segment is split or merged, how much identity continuity matters versus creating new segment ids cleanly?

**JF Note**
I think I kind of touched on this above. I think that such edits should just change the segment directly. a merge shoudl either retain one of the segments' ID or just be a new ID all together. If this opens other issues, please tell me and don't hesitate to push back if you think otherwise. This applies generally to all my notes and comments.
**End JF Note**

Updated conclusion:
- For v1, direct mutation of current segment state is a reasonable simplifying default.
- The main thing the implementation must keep consistent is references from collections, exports, and UI state after split/merge operations.
- I do not think we need a more elaborate identity/versioning scheme yet.

### 2. ReviewItem Granularity

Should review items point mainly to whole segments, or also to sub-intervals inside a segment?

**JF Note**
I think it makes a lot of sense to support referring to a sub-interval. Yes.
**End JF Note**

Updated conclusion:
- Review items should be able to refer either to a whole segment or to a sub-interval within a segment.

### 3. Collection Notes/Media

Should notes/media be part of the base Collection entity in v1, or added as an optional extension later?

**JF Note**
Later is fine.
**End JF Note**

Updated conclusion:
- Collection notes/media should be treated as an optional extension rather than base v1 complexity.

### 4. ExportArtifact Storage

Should saved exports store:
- only metadata plus reproducible source references
- or also the rendered payload/artifact itself

**JF Note**
Whatever is needed to re-share the same content and to view it within the app
**End JF Note**

Updated conclusion:
- Saved exports should retain enough payload or renderable state to be viewable in-app and re-sharable without lossy regeneration.

**JF Note**
As a general comment, I have a sense that you are a bit over engineering the model. That said, you might have valid reasons. So, let's discuss those.
**End JF Note**

Updated conclusion:
- That concern is valid.
- The safest simplification rule for v1 is:
- keep only the entities that directly support timeline correctness, user correction, sync, and exports
- avoid rich historical versioning unless a concrete v1 requirement truly needs it
- In that spirit, the draft should be read as a conceptual shape, with a bias toward collapsing edit history and long-lived review history unless implementation needs prove otherwise.
