# Blackbox V1 Scope Spec

This document defines a rough v1 scope for Blackbox.

It is more concrete than brainstorming and architecture overview, but it is still not a full implementation plan.

Its purpose is to answer:
- what v1 should do
- what v1 does not need to do yet
- what quality bar v1 should meet
- what major tradeoffs v1 should make

## Purpose Of v1

Blackbox v1 should prove the core product idea:

An iPhone + Apple Watch system can passively capture meaningful movement/activity history, organize it into semantic segments, let the user review and correct those segments, and present the result in a timeline that feels useful enough to become a trusted personal record.

v1 does not need to prove the entire long-term vision.

It needs to prove that the core loop is valuable:
- record passively
- infer enough meaning
- surface ambiguity honestly
- allow lightweight correction
- preserve meaningful history

## v1 Product Definition

Blackbox v1 is:
- a local-first movement/activity journal
- centered on iPhone, with Apple Watch participation
- focused on passive recording
- centered on timeline, segment detail, and collections
- capable of export-oriented sharing

## v1 Success Criteria

v1 is successful if it can do all of the following well enough:
- record activities passively in the background often enough to reduce dependence on manual start/stop tracking
- produce a timeline of meaningful segments that usually feels plausible
- let the user easily fix wrong or uncertain segments
- retain enough information for segment summaries and later manual reclassification
- support basic collections and basic sharing/export
- continue functioning locally when connectivity is poor or unavailable

**JF Note**
I'd say the number one success criteria for v1 is low false positives and also low false negatives. In other words, don't miss real activities and don't identify activities that never happend. Infering the second level activity type (e.g. walking vs hiking) is not all that important. If we can do that with reasonable confidence then great. Otherwise, the user can make those precision edits if they care at all.
**End JF Note**

Updated conclusion:
- The top v1 quality target is not subtype richness. It is low false positives and low false negatives at the segment-detection level.
- In practical terms:
- do not miss meaningful real activities too often
- do not invent activities that never really happened
- secondary precision in labels matters less than reliable capture and boundary detection

## v1 In Scope

### 1. Platforms

In scope:
- iPhone app as the primary product surface
- Apple Watch app as a participating capture and activity-aware companion app

Not required in v1:
- web UI
- Android app
- Garmin or third-party wearable integration

### 2. Core Recording

In scope:
- passive background capture on iPhone
- watch data participation
- local storage of observations and semantic history
- segmentation of captured history into meaningful activity periods
- support for pause events within a segment

### 3. Visible Activity Classes

In scope for visible v1 classes:
- stationary
- walking
- running
- cycling
- hiking, when confidence is reasonably strong
- vehicle
- flight
- water activity
- unknown / mixed / uncertain

Not required in v1 as visible classes:
- driving vs train vs bus vs motorcycle
- swimming vs rowing vs sailing vs speed boat
- sleep

**JF Note**
I'd add Hiking (tentatively) to the scope. I'm not sure if it is any different than walking in how we end up treating it but I think it shouldn't be that difficult to differentiate. Walking combined with elevated heart rate in some of the spots and/or out of town sounds like hiking to me. How would you define hiking vs. walking? Maybe it's just a potato potato thing. One user would refere to a certain activity as walking while another would refer to it as hiking? Either way, the user should be able to select whatever they want to classify that activity as.

Regarding other subclasses (drive vs. motorcycle vs. train etc.) Even if we leave the sub classing to the user, I think we should still include them in scope.

I'm OK with sleep being out of scope for v1
**End JF Note**

Updated conclusion:
- Hiking should be tentatively in scope as a visible v1 class when confidence is good enough.
- It should not force the classifier to overcommit; walking remains the safer fallback when signals are ambiguous.
- Subclasses such as driving, motorcycle, train, and similar should remain out of scope for automatic visible inference, but should be available for user-driven manual reclassification if the user cares.
- When the user chooses one of those narrower labels, the UI should surface that user-selected label rather than collapsing everything back to the broad visible class.


### 4. Segment Semantics

In scope:
- start/end time
- visible activity class
- confidence / needs-review state
- quality state
- route and map summary where relevant
- core stats such as duration, distance, elevation, speed where relevant
- heart-rate or other health overlays when meaningful and available

### 5. Timeline Experience

In scope:
- timeline-first home
- timeline cards for segments
- timeline cards for collections
- timeline grouped by day
- timeline filters for activity type, review state, confidence/quality-related states
- timeline search for title and location/area

### 6. Segment Detail And Editing

In scope:
- map-forward detail for movement-heavy segments
- summary stats
- quality/confidence display when relevant
- retitle
- reclassify
- split
- trim
- delete
- add note/tag
- add segment to collection
- show a user-selected narrower label when one exists

Not required in v1:
- point-by-point route editing
- advanced forensic inspection of raw sample streams in the main UI

### 7. Collections

In scope:
- create collections
- show collections on timeline
- allow collections to contain multiple segments
- collection detail view
- rename collections
- add/remove segments
- basic notes/media support if low effort, otherwise defer

Potential simplification:
- nested sub-collections can be deferred if they add too much complexity

### 8. Review And Ambiguity

In scope:
- low-confidence segments
- needs-review markers
- suspicious data surfacing
- review primarily via timeline filters and card markers

Not required in v1:
- a sophisticated separate review workflow if timeline-first review is enough

### 9. Export / Sharing

In scope:
- quick-share export flow
- export from segment or collection
- lightweight selection of what attributes to include
- save export as an artifact

Not required in v1:
- deep destination-specific customization
- rich story-builder editor
- web-link sharing model

### 10. Sync / Cloud

In scope:
- cloud-backed durability
- opportunistic sync
- local-first operation
- adaptive syncing based on network/battery policy

Not required in v1:
- multi-user cloud architecture
- web consumption surface
- sophisticated server-side analytics

**JF Note**
Multi user cloud should be taken into account to make that transition as easy as possible and not require complex data migration. Other than that, no need to worry about it for v1.
**End JF Note**

Updated conclusion:
- Multi-user cloud architecture is not part of v1 delivery, but v1 should avoid storage assumptions that would make later tenant separation painful.

## v1 Explicitly Out Of Scope

Unless implementation unexpectedly makes them nearly free, these should be treated as out of scope for v1:
- sleep as a first-class passive segment type
- broad longitudinal health dashboards
- deep transport subtype classification
- deep water-activity subtype classification
- nested collection hierarchies
- Android
- web app
- Garmin integration
- social/public feed model
- heavy cloud-side intelligence
- automatic reinterpretation of old settled history

## v1 User Experience Bar

The app does not need to be perfect.

It does need to feel trustworthy enough that:
- a user can leave it running
- later open the timeline
- recognize most of what happened
- quickly fix what is wrong
- feel that the product is reducing memory and tracking burden rather than creating more work

**JF Note**
All true and also worth noting that for V1, I will be the only user.
**End JF Note**

Updated conclusion:
- v1 should be optimized for a single-user deployment and workflow.
- That should simplify priorities, testing assumptions, and backend scope, while still leaving room for future multi-user evolution.


## v1 Quality Bar

The app should be considered good enough for v1 if:
- passive recording works reliably enough in ordinary day-to-day usage
- segment boundaries are not obviously chaotic most of the time
- real meaningful activities are not missed too often
- spurious activities are not created too often
- visible classifications are conservative and not overconfident
- bad data does not silently poison the timeline too often
- edits and collections feel stable
- sync failures do not break local history

## Key v1 Architectural Commitments

v1 should commit to:
- local-first correctness
- separation between observations and durable semantic history
- separation between segmentation and classification
- segment-centric editing
- cloud-backed durability
- watch participation with at least limited standalone usefulness

## Likely v1 Simplifications

These simplifications are probably healthy:
- visible taxonomy remains broad
- watch acts as a capture/current-activity companion more than a full parity client
- review is timeline-based rather than a complex separate subsystem
- export is quick-share focused rather than deeply customizable
- health data is overlay/context rather than a full health analytics product
- collections are useful but not yet fully rich storytelling objects

## Open v1 Decisions Still Needing Resolution

These are still scope-level questions rather than implementation details:
- How much standalone watch recording is required in v1 versus later?
JF: Preferably, as much as a full day worth of data recording
- Are notes/media inside collections truly in scope, or should collections be segment-only in v1?
JF: Would be nice to have. Lower priority.
- Are saved exports first-class from day one, or can they be partially deferred?
JF: Not sure what partially deferred means but my approach is, if it's in scope then it is first-class.
- What minimum health overlay data is required for v1?
JF: Heart rate will suffice for V1
- What level of sync/storage setup is actually feasible for v1 without overbuilding the backend?
JF: Not sure how to answer this. Give me a few options to choose from

Updated interpretation:
- Standalone watch usefulness should be meaningful in v1, not token.
- Notes/media in collections are optional and lower priority than the core timeline/segment/collection loop.
- If saved exports are in scope, they should be treated as first-class from the start.
- Heart rate is sufficient as the v1 health overlay baseline.

## Sync / Storage Options For v1

To answer the remaining sync/storage question, these look like the most realistic scope options:

### Option A: Minimal Cloud Durability

What it means:
- local-first app
- basic cloud backup of durable semantic data
- minimal selected support-data upload
- limited backend complexity

Pros:
- fastest route to a usable v1
- least backend overhead
- easiest to keep focused

Cons:
- less robust recovery during long in-progress activities
- less flexibility for future web/multi-device work

### Option B: Balanced Local-First Cloud

What it means:
- local-first app
- durable semantic sync
- adaptive in-progress uploads for important or long activities
- enough backend structure to support future expansion without overbuilding

Pros:
- best fit with the current product vision
- supports safer long-activity capture
- keeps future options open

Cons:
- more engineering scope than minimal backup-only cloud

### Option C: Ambitious Cloud-Ready v1

What it means:
- local-first app
- richer support-data sync
- stronger export persistence
- clearer path toward future multi-device/web use

Pros:
- fewer later architectural reversals
- more future-proof

Cons:
- higher risk of overbuilding
- slower path to proving the core passive-capture loop

Current recommendation:
- Option B looks like the right default unless you deliberately want to optimize for the fastest possible single-user prototype.

## Recommended v1 Thesis

If v1 is disciplined, its thesis should be:

Blackbox can replace unreliable manual start/stop activity tracking with a passive, local-first timeline of meaningful movement segments that the user can trust, correct, organize, and share.

## Natural Next Step After This Doc

Once this scope is accepted, the most natural next documents are:
- a concrete domain model/schema draft
- a feature-by-feature v1 requirements spec
- a technical capability assessment for iPhone + Apple Watch APIs
- a phased implementation plan
