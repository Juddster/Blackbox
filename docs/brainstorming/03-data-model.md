# Blackbox Data Model Brainstorming

This document holds the rough data model brainstorming branch for Blackbox.

The goal here is not to design tables or implementation details yet. The goal is to shape the conceptual entities and relationships so the product has a coherent structure.

## Brainstorming Branch 2: Rough Data Model Shaping

### Core Objective

The data model should support all of the following at once:
- passive capture
- uncertain inference
- segment-level editing
- user-defined collections
- health and quality overlays
- future reinterpretation of earlier segments
- export-oriented sharing
- later addition of non-movement segments such as sleep

That means the model should be flexible enough to preserve meaning without being so abstract that everything becomes vague.

### Likely Core Layers

The current product thinking already suggests these layers:
- samples
- segments
- collections
- exports

And likely orthogonal overlays:
- confidence
- quality state
- health context
- user edits
- annotations

### Candidate Core Entities

At a conceptual level, the model likely needs at least these entities.

#### 1. Observation

Represents a captured data point or short-lived support datum.

Examples:
- location fix
- speed sample
- elevation sample
- motion reading
- heart rate sample
- battery state snapshot
- connectivity snapshot

Characteristics:
- timestamped
- source-specific
- may be high-volume
- may be transient or downsampled later
- not usually the main thing the user interacts with

Role in the product:
- supports inference
- supports reprocessing
- supports derived summaries

#### 2. Segment

Represents a continuous or near-continuous inferred activity period.

Examples:
- walking segment
- running segment
- vehicle segment
- water activity segment
- uncertain mixed segment

Characteristics:
- start and end time
- visible class
- confidence
- quality state
- summary attributes
- optional pause events inside the segment
- editable by the user

Role in the product:
- likely the main unit of timeline interaction
- likely the main unit of review and correction

#### 3. Pause Event

Represents an interruption or stop within a segment that should not necessarily split it.

Examples:
- stoplight during vehicle travel
- rest break during a hike
- short stop during a ride

Characteristics:
- start and end time
- optional reason or inferred type
- tied to a parent segment

Role in the product:
- helps preserve the distinction between one activity with pauses and several independent segments

#### 4. Segment Interpretation

Represents the inferred or assigned meaning of a segment.

This may sound redundant with Segment, but it may be useful conceptually to separate:
- the existence of a detected segment
- the current best interpretation of what that segment is

Possible contents:
- visible class
- candidate labels
- confidence scores
- supporting evidence summary
- whether user review is needed

Why this separation may matter:
- the segment remains the same time-bounded thing
- the interpretation can change over time due to better heuristics or user correction

#### 5. Segment Summary

Represents the durable computed attributes of a segment.

Examples:
- duration
- distance
- route geometry
- elevation gain
- average speed
- max speed
- heart rate summary
- pause count
- quality flags

Role in the product:
- supports timeline cards, detail pages, exports, and quick comparison

#### 6. Annotation

Represents user-authored meaning attached to a segment or collection.

Examples:
- title
- notes
- tags
- manual classification
- comments about bad data

Role in the product:
- lets the user enrich the journal without mutating raw observations

#### 7. Edit Record

Represents a user action that changes how the system treats history.

Examples:
- split segment
- merge segments
- reclassify segment
- trim bad interval
- delete segment
- group segments into collection

Why it may matter:
- user edits are part of the history of meaning
- some edits may need to be reversible or at least auditable

#### 8. Collection

Represents a user-meaningful grouping of one or more segments.

Examples:
- Saturday motorcycle ride
- triathlon race day
- travel day
- vacation outing

Characteristics:
- can span multiple segments
- can contain mixed activity types
- may have its own title, notes, tags, and summaries

Role in the product:
- supports storytelling
- supports sharing
- supports higher-level organization

#### 9. Export

Represents a prepared artifact for sharing or archiving.

Examples:
- route card
- animated playback
- summary image
- story-like timeline package
- Strava-style export package

Characteristics:
- derived from one or more segments or collections
- destination-aware
- presentation-oriented

Role in the product:
- keeps sharing separate from the core historical record

#### 10. Review Item

Represents something the system wants the user to verify or inspect.

Examples:
- low-confidence classification
- suspicious GPS interval
- ambiguous water activity
- likely bad route segment

Role in the product:
- operationalizes your "honest ambiguity" principle

### Likely Important Relationships

At a high level, the model likely needs relationships like:
- observations contribute to segments
- segments have summaries
- segments have interpretations
- segments may contain pause events
- segments may have annotations
- segments may generate review items
- collections group segments
- exports derive from segments or collections
- edit records modify or reinterpret segments and collections

### The Most Important Conceptual Separation

The biggest modeling question may be whether to keep these clearly separate:
- what was observed
- what was inferred
- what was corrected by the user
- what was published/shared

My current view is: yes, that separation is essential.

Why:
- it preserves trust
- it makes reinterpretation possible
- it avoids destructive editing of raw meaning
- it supports future reprocessing without losing the user's edits

### A Possible Mental Model

One useful way to think about the system is:

Observations become candidate segments.
Segments receive interpretations and summaries.
Users can revise those interpretations and organize segments into collections.
Collections or segments can produce exports.

That is a cleaner mental model than trying to make one object do everything.

### Design Recommendation So Far

If I had to recommend the rough conceptual backbone now, it would be:
- Observation
- Segment
- SegmentInterpretation
- SegmentSummary
- PauseEvent
- Annotation
- EditRecord
- ReviewItem
- Collection
- Export

That is probably enough structure to support the product without overfitting too early.

## Questions For This Branch

### 1. Segment vs Interpretation

Does it feel right to separate:
- the existence of a segment
- the interpretation of that segment

Or do you feel that is overcomplicating the conceptual model?

Your thoughts:
It feels like overcomplicating but, at this point, I already find it hard to wrap my mind around the whole structure so I will rely on your judgment. You're the one who has to code it, maintain it, test it, etc. Whatever helps you get the best results (durability, stability, quality, etc) is fine with me

Updated conclusion:
- Keep the conceptual separation between Segment and SegmentInterpretation.
- It is slightly more abstract up front, but it buys durability: the same segment can survive reinterpretation by heuristics or user edits without becoming conceptually unstable.
- This is one of those cases where a little extra structure now likely prevents a lot of confusion later.

### 2. Edit History

Do you want user edits to be treated as first-class records in the model, or is it enough to just update the current state?

Examples:
- keep a record that a segment was reclassified
- keep a record that a bad interval was trimmed
- keep a record that a collection was manually assembled

Your thoughts:
Exact same response as for #1

Updated conclusion:
- Treat edit history as first-class in the conceptual model.
- Even if the product UI does not expose a full audit log early, the model benefits from remembering that a segment was split, trimmed, reclassified, or grouped.
- This supports reversibility, trust, debugging, and later refinement.

### 3. Collections

Should collections be able to contain:
- only segments
- segments plus freeform notes/media
- segments and nested sub-collections

Your thoughts:
I think next sub-collections is a great idea. freeform notes and media too

Updated conclusion:
- Collections should be richer than a flat list of segments.
- They should be able to contain segments, notes/media, and nested sub-collections.
- That makes collections a true storytelling and organization layer rather than just a tag bucket.

### 4. Review Items

Should review items be their own first-class object, or just a property on segments?

Your thoughts:
Same as answer to #1

Updated conclusion:
- Review items should be first-class objects.
- They may often attach to segments, but they represent workflow state, not just segment metadata.
- This becomes more important once review can be triggered by quality issues, ambiguity, or future non-segment events.

### 5. Exports

Should exports be thought of as persistent saved artifacts, or mostly transient generated outputs?

Your thoughts:
I mean, I was going to say transient but I can see the value in persisting it (kind of like a magazine of published stories, does that make sense?)

Updated conclusion:
- Exports should conceptually be persistable artifacts, even if some are generated on demand.
- The "magazine of published stories" framing is useful: an export is not merely a function call result, it can become part of the user’s curated history.

### 6. Non-Movement Segments

Does it make sense for sleep later to be "just another segment type" at the conceptual level, or should non-movement states live in a parallel structure?

Your thoughts:
Just another segment type makes sense to me

Updated conclusion:
- Non-movement states such as sleep should live within the same segment concept.
- That keeps the model more uniform and reduces the need for a parallel semantic structure later.

## Data Model Resting State

This branch now has a clearer recommended backbone.

### Recommended Core Concepts

- Observation
- Segment
- SegmentInterpretation
- SegmentSummary
- PauseEvent
- Annotation
- EditRecord
- ReviewItem
- Collection
- Export

### Recommended Structural Principles

- Keep observed, inferred, user-corrected, and published/shared layers distinct.
- Let segments be stable time-bounded units.
- Let interpretations change without replacing the underlying segment.
- Let edits be recorded as meaningful history, not just overwritten state.
- Let collections be rich, composable objects rather than simple group labels.
- Let exports exist as curated artifacts, not only transient renders.
- Let non-movement states fit into the same semantic segment model.

### Simplified Mental Model

At the conceptual level:

- Observations are captured.
- Observations support one or more Segments.
- Each Segment has a current Interpretation and one or more Summaries or derived attributes.
- Segments may contain PauseEvents.
- Users may attach Annotations and create EditRecords.
- The system may create ReviewItems.
- Users or the system may group Segments into Collections.
- Collections or Segments may produce Exports.

### Why This Model Seems Strong

- It preserves room for uncertainty and reinterpretation.
- It supports both passive automation and manual curation.
- It cleanly separates history from presentation.
- It can absorb later features like sleep, richer review workflows, and more sophisticated sharing without changing the conceptual center.

### Practical Consequence For Later Design

The UI and storage model should probably revolve around Segment, Collection, and ReviewItem as the main user-facing objects, with Observation and EditRecord mostly supporting them in the background.

## Ready To Move On

The next natural branch is:
- UI concepting
