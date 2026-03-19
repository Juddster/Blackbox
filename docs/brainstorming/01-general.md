# Blackbox App Brainstorming

## Purpose

This document is the working space for early brainstorming about the Blackbox app.

Current intent:
- Capture a durable, meaningful record of life events and conditions using iPhone, Apple Watch, Health data, and potentially other sources later.
- Preserve enough history to be useful long-term without storing wasteful amounts of low-value raw data.
- Use the iPhone app both as the primary data collector and as the primary interface for reviewing and correcting data.
- Stay in brainstorming mode for now. This document is not yet a plan or specification.

## Project Idea

Working concept:
- A personal "black box" similar in spirit to an airplane black box.
- The app continuously captures relevant signals from available sensors and connected sources.
- Data is cleaned and interpreted into meaningful records such as movement, activity, health context, environment, and notable events.
- Data is uploaded to the cloud efficiently, taking into account network quality, battery cost, storage cost, and bandwidth cost.
- The app presents the data in context-sensitive ways and allows correction where it makes sense.

Examples already discussed:
- Track location, route, speed, elevation, and travel path.
- Infer what kind of activity is happening: running, hiking, vehicle travel, driving, swimming, rowing, sailing, boating, commercial flight, etc.
- Detect bad or suspicious location data, such as GPS jamming or tunnel-related gaps.
- Flag ambiguous cases for user review instead of pretending confidence is higher than it is.
- Leave room for future web UI, Android support, Garmin or other wearable integrations, and additional input sources.

## Core Product Tensions

These appear to be the main tensions shaping the product and architecture.

### 1. Capture Everything vs Capture What Matters

The initial instinct is to capture as much as possible, but long-term value likely comes from layered retention rather than permanent storage of every raw sample.

Useful model:
- Short-term: high-frequency raw or near-raw data
- Medium-term: cleaned and normalized samples
- Long-term: derived segments, activities, trips, summaries, anomalies, and user-corrected records

Open thought:
- The real goal may not be "store everything forever"
- The better goal may be "never lose what is meaningful"

**JF Note**
Exactly. The idea is not to store all the raw data. It is rather to use as much sensor data as needed to infere what the activity is and then only persist for long term the details of the activity (may be different for each type of activity, e.g. speed for driving, heart rate for running and hicking). For location related activities, we will always want to keep a resolution high enough to be able to plot a smooth path on the map even when zoomed in to a reasonable point.

The initial incentive comes from often forgeting to start/pause/stop tracking a run, a hike or a motorcycle ride. I want the app to always run in the background, and use whatever location and sensor data available to detect activities I care about, categorize the activity to the extent possible, detect when I pause, when I resume and when I switch to a different activity.

As for editing, I wouldn't edit a series of locations. But I would for example delete a segment (identified by begin/end timestamp) if I think it is wrong (GPS jamming) or for whatever other reason. I might want to change the categorization of an activity, split an activity into one or more and categorize each (or just give a manual title to each section). Those are the kind of editing I have in mind. That implies that we need to keep enough data so that if I recategorize an activity or part of it, we still have the relevant data for that type of activity.
**End JF Note**

Updated thought:
- The retention model should likely be activity-aware rather than globally uniform.
- The system should preserve enough supporting detail to survive later recategorization of a segment.
- Editing is segment-level and semantic, not point-level. That simplifies both UX and storage.

### 2. On-Device Intelligence vs Cloud Intelligence

It likely makes sense to do more on-device than most products initially attempt.

Good candidates for on-device handling:
- sensor cleanup
- anomaly detection
- initial activity inference
- data batching and compression
- adaptive upload scheduling based on battery/network state

Good candidates for cloud handling:
- durable storage
- cross-device sync
- heavier analytics
- retrospective reprocessing when inference improves
- future web and multi-platform access

**JF Note**
I am not sure about cloud handling. Not initially anyway.
**End JF Note**

Updated thought:
- For now, the best framing is probably "cloud as durable sync and storage, not as primary intelligence."
- That pushes the early architecture toward a local-first product, with the cloud mostly acting as backup, history, and future expansion surface.

### 3. Accuracy vs Battery vs Cost

Continuous sensing competes directly with:
- battery life
- device thermal constraints
- cloud storage cost
- cloud bandwidth cost
- processing cost

The product will need an explicit stance on acceptable tradeoffs.

**JF Note**
I think the app should be able to take cues from the iphone switching to Low Power Mode but, at the same time, it should check with the user what exactly it wants to do. The user should be able to set policies fepending on Low power mode as well as battery level. But they should also be able to select and override usage level because they may know they have a powerbank or that they are just half an hour away from access to an outlet. The app should notify the user that battery usage is high and at this rate the battery may run flat in such and such time. But the user knows best and it is always their prerogstive to overide. 
**End JF Note**

Updated thought:
- Battery policy looks user-configurable rather than fixed.
- This suggests the product may need explicit operating modes such as aggressive, balanced, and battery-preserving, plus override rules tied to battery percentage and Low Power Mode.

### 4. Automated Inference vs User Control

The product should infer useful meaning automatically, but still let the user correct it.

Likely principle:
- Raw observation, inferred interpretation, and user correction should be treated as different layers of truth.

Examples:
- Observed: location points and motion samples
- Inferred: "likely driving"
- Corrected by user: "actually passenger in a bus"

**JF Note**
Correct, and I also addressed some of this in my previous Notes.
**End JF Note**

Updated thought:
- User correction is not just a repair tool. It is part of the core product loop.
- The app should probably keep a distinction between observed facts, inferred segment type, and user-authored segment meaning.


### 5. Seamless Logging vs Explainability

If the system labels an activity, it may be important to explain why.

Example:
- "Marked as driving because speed pattern, acceleration profile, and route matched roads."

Explainability could improve:
- trust
- debugging
- correction UX
- future model improvement

**JF Note**
Right, it may be useful for debugging and improving the huristics.
**End JF Note**

Updated thought:
- Explainability now looks like an advanced layer, not a front-and-center consumer feature.
- A lightweight explanation may still be useful in the UI when confidence is low or a segment is flagged for review.

## Product Shape Emerging From Discussion

Current framing:
- This is not only a tracker.
- It is a context-aware personal event recorder.
- It should build a semantic timeline from raw streams.
- The UI should adapt to the current or inferred context instead of presenting the same generic dashboard all the time.

Implication:
- A run, a drive, a flight, and a hike should not all look the same in the product.

**JF Note**
Correct
**End JF Note**

Updated thought:
- The product is now more clearly an always-on movement/activity journal than a general-purpose life recorder in v1.
- That sharper scope is useful. It reduces the risk of designing for too many data classes too early.

## Data Model Direction

Early intuition suggests a layered data model.

Possible layers:
- Raw sensor observations
- Cleaned and normalized samples
- Segments or sessions
- Inferred activities
- Derived summaries
- Anomalies or confidence issues
- User corrections and annotations

The durable, high-value unit may not be individual sensor points.
It may be semantic segments such as:
- "Morning run"
- "Drive from home to airport"
- "Commercial flight from TLV to JFK"
- "Uncertain location gap while in tunnel"

**JF Note**
Sounds right. Apply whatever you learned from my previous comments
**End JF Note**

Updated thought:
- The most important durable entity may be the activity segment.
- Supporting data should be retained according to what future edits and recategorization require, not according to a blanket raw-data policy.

## Activity Inference Direction

A useful principle is confidence-scored inference rather than hard labels.

Possible representation:
- candidate activity labels
- confidence score
- supporting signals
- ambiguity state
- whether user review is needed

Examples of activity classes already mentioned:
- stationary
- walking
- running
- hiking
- cycling
- vehicle travel
- driving
- train
- bus
- swimming
- rowing
- sailing
- speed boat
- commercial flight

Important open reality check:
- Some of these are much easier to infer than others.
- The product should probably distinguish between activities that are robustly detectable and activities that are only weakly inferable.

**JF Note**
I would just clasify based on highest confidence. If the confidence is below some threshold, the activity should be visibly tagged with a confidence level color and percentage tag so the user can verify it.

Is it even possible to distinguish between sailing and swiming?
I guess it is possible to infer that it is water related from the location. So, that with the rate of movement and cadence can get us a long way.

How can we infer comercial flight? Does the phone or watch have any sensor for air preasure? Do location services work within the cabin of an airliner? Or do we just infer from the location and time diff between takeoff and landing?
**End JF Note**

Updated thought:
- Highest-confidence classification is reasonable for the primary label, but the runner-up candidates may still be worth keeping internally for review and future reprocessing.
- Water-related activities are likely to be one of the more difficult inference classes and may need a broader "water activity" bucket before trying to split into swimming, rowing, sailing, and motor boating.
- Flight detection may be practical as a composite inference problem rather than a single-sensor one: airport context, large distance jump, speed profile, altitude or pressure changes when available, loss or degradation of normal ground-travel patterns, and arrival at another airport-like context.

## Bad Data and Ambiguity Handling

This seems central to the product rather than a side case.

Examples:
- GPS jamming
- tunnel transit
- urban canyon drift
- temporary loss of signal
- impossible jumps in speed or position
- conflicting signals across sensors

A better model than "location present or absent" may be:
- trusted
- degraded
- implausible
- interpolated/reconstructed
- flagged for review

This could become a distinctive strength of the app.

**JF Note**
Right
**End JF Note**

Updated thought:
- Trust state should likely attach both to individual samples and to whole segments.
- A user deleting a bad segment because of jamming is a strong signal that data quality handling needs to be a first-class workflow, not just a background cleanup step.

## UI Direction

The UI should likely be built around context and semantics rather than raw feeds alone.

Potential UI patterns:
- adaptive activity-specific screens
- timeline of meaningful segments
- map-first exploration for movement-heavy periods
- review queue for ambiguous or suspicious events
- correction tools for relabeling or annotating segments
- summary views across time

Possible examples:
- Running UI: pace, route, elevation, splits
- Driving UI: route, stops, durations, unusual deviations
- Flight UI: takeoff/landing detection, airports, time zones, duration

**JF Note**
Right
**End JF Note**

Updated thought:
- A review workflow is becoming more important than a generic dashboard.
- The app should make it easy to spot "uncertain", "possibly wrong", and "needs confirmation" segments without forcing constant manual attention.

## Future Expansion Already In Scope

Possible future directions already mentioned:
- web UI
- Android app
- Garmin integration
- support for additional watches or wearables
- more data sources beyond Apple sensors and Health

Architectural implication:
- The system should probably avoid assuming "Apple-only forever" even if Apple is the v1 platform focus.

**JF Note**
Also worth taking into account that this might turn into an appstore app. So each user has their own data. This may have further privacy and data security implications. Not something to worry about at the moment but worth taking into account when setting up the cloud project and database layout and segmentation per user.
**End JF Note**

Updated thought:
- Even if multi-user support is not an immediate concern, tenant separation should not be an afterthought in the eventual cloud model.
- That matters less for brainstorming the product, but it does matter for avoiding a dead-end storage model later.

## Provisional Product Principles

These are not final decisions. They are current working principles inferred from the discussion.

- Meaning beats volume.
- Confidence beats false precision.
- Ambiguity should be surfaced, not hidden.
- On-device intelligence is valuable for privacy, battery, and cost.
- The long-term product is a semantic personal history, not just a sensor dump.
- User corrections should improve the usefulness of the record.

**JF Note**
Right
**End JF Note**

Updated thought:
- The current principles are holding up, but now they point more clearly toward segment-centric design and local-first behavior.

## Key Clarifying Questions

These are the questions that currently seem most important because they will strongly affect product direction and architecture.

### 1. Primary Value of v1

Which of these is closest to the main value of the first version?
- lifelog timeline
- movement journal
- health and activity memory
- personal forensic record
- something else

**JF Note**
I'd say "movement/activity journal"
**End JF Note**

Updated conclusion:
- v1 is best framed as an always-on movement/activity journal with timeline reconstruction and semantic activity segments.


### 2. Privacy Posture

How privacy-sensitive should the default system behavior be?

Questions to think through:
- Should raw location be stored in the cloud forever?
- Should some data be transformed before upload?
- Should some data remain local-only unless explicitly preserved?

**JF Note**
We should upload whatever we need for the activity. We should also consider uploading raw transient data for activity that is progress, if it is needed later for the clasification.

I am not worried about privacy for now. Personally, I don't care. Once this becomes a multi user app and cloud service then we'll have to worry about privacy. It also depends on where the data is stored. For example, if it is stored in the user's google drive than it is more their problem. If it is stored in a cloud storage shared among all users then we need to be more vigilant about privacy and data security
**End JF Note**

Updated conclusion:
- Current posture is pragmatic rather than privacy-maximalist.
- The more important present question is not "how little can we upload" but "what transient support data is worth uploading, for how long, and under what retention rule."



### 3. Battery Budget

How much battery cost is acceptable for true always-on logging?

Questions to think through:
- Is this allowed to be noticeably battery-hungry?
- Is there a hard cap on acceptable impact?
- Should the app become more aggressive only in certain contexts?

**JF Note**
I addressed this in one of my previous notes above
**End JF Note**

Updated conclusion:
- Battery behavior should be policy-driven, user-visible, and overrideable.

### 4. Meaning of "Edit the Data"

What kinds of edits should the user be allowed to make?

Examples:
- correct activity labels
- add notes
- merge or split segments
- fix routes manually
- delete sensitive intervals
- override inferred conclusions

**JF Note**
I addressed this in one of my previous notes above
**End JF Note**

Updated conclusion:
- Edits should focus on deleting, splitting, retitling, and recategorizing segments rather than manipulating raw samples.

### 5. Explainability

Should the app explain why it inferred an activity or flagged something as suspicious?

Possible modes:
- no explanation
- simple explanation
- detailed evidence view

**JF Note**
I addressed this in one of my previous notes above

Such explanation is only useful for debugging and improving the huristics. It may be interesting for the curios user (if they want to dig deeper)
**End JF Note**

Updated conclusion:
- Explainability belongs primarily in diagnostics and optional drill-down views.


### 6. Retention Philosophy

Which principle is closer to what you want?
- nothing is ever deleted
- nothing meaningful is ever deleted

**JF Note**
- nothing meaningful is ever deleted
**End JF Note**

Updated conclusion:
- Retention should optimize for preserving future usefulness, not preserving every byte.

## Additional Questions That May Matter Later

These are not urgent yet, but they are likely to become important.

- Who is the product for in v1: only you, or eventually many users?
- Is this meant to be primarily private, or eventually shareable in some limited way?
- Should the app optimize for passive recording or also support active session-based use?
- Do you care more about timeline reconstruction or real-time coaching/feedback?
- Should the system prefer local reliability first, then sync later?
- How much manual curation are you actually willing to do?
- Should the product record everything equally, or prioritize exceptional periods and places?

**JF Note**
1. In V1 only for me. Eventually, potentially for many users.
2. Primarily private, but I will want to share a drive or a whole day's ride or a hike, a run. or upload an activity to e.g. Strava.
3. I'm not sure I understand the question. What is active session-based? you mean something like telling the app I'm starting a type of activity and then when I stop? I guess I could help the app by telling it what type of activity I'm going to engage in (rather the fixing it after the fact). Or is there more to it?
4. Timeline reconstruction
5. I don't understand the question regarding "local reliabilty first, sync later"
6. If by Manual curation you mean fixing infered activity type clasification and various editing such as spliting, deleting, tagging, titeling. Sure. Uploading an activity, very rare, for example in case the device was down and I want to add the activity for posterity.
7. Record everyhing all the time (as long as there is meaningful data to record). 
**End JF Note**

Updated interpretation:
- v1 is single-user in practice, but should avoid assumptions that would make later multi-user evolution painful.
- The product should optimize for passive recording first, with optional user hints before an activity rather than requiring explicit session starts.
- "Local reliability first, sync later" means the app should continue working well even when offline, with upload being opportunistic rather than required for correctness.

## Working Architecture Intuition

This is not a plan. It is just the current conceptual direction.

Likely broad shape:
- on-device capture
- on-device normalization and quality checks
- local segment/event builder
- confidence-based activity classifier
- adaptive uploader
- cloud storage with tiered retention
- semantic timeline UI based mostly on derived segments rather than raw sensor points

Updated architecture intuition:
- local-first capture and segmentation
- activity-aware retention rules
- segment-centric editing model
- confidence-tagged classification with optional review queue
- cloud as backup/history/sync surface, not necessarily heavy inference infrastructure at first


## Open Brainstorm Space

Use this section freely for anything that comes up while answering the questions above.

**JF Note**
In V1.1, I would also like to record sleep data. So the phone is charging (or not) and not moving but the watch has its sensors.
**End JF Note**

Updated thought:
- Sleep begins to widen the product from movement/activity journal into broader personal-state journaling.
- That may be a good v1.1 expansion because it still fits the same model of passive sensing plus semantic segments, but it is worth treating as a separate scope boundary from movement-focused v1.

## Additional Questions Raised By Your Notes

These feel like the next most useful questions.

### 1. Activity Taxonomy Depth

How deep should the first taxonomy go?

Examples:
- broad classes only: stationary, walking, running, cycling, vehicle, water activity, flight
- moderate depth: distinguish driving vs train vs bus, hiking vs running, swimming vs boating
- deep taxonomy: sailing vs speed boat vs rowing, motorcycle vs car, etc.

Why this matters:
- It changes both inference difficulty and data retention needs.

**JF Note**
Obviously. The deeper the better. but, for me, broad suffices. Can we start with broad classes and improve later or does this have structural implications that will be more difficult to deepen the taxonomy later down the line?
**End JF Note**

Updated conclusion:
- Yes, broad classes can be a safe starting point if the underlying model stores enough supporting evidence and allows subtype refinement later.
- The structural implication is mainly in the data model: the system should store both a displayed label and a more flexible internal classification record with confidence and candidate subtypes.
- In other words, taxonomy depth can evolve later if the architecture avoids baking a single flat enum into everything.

### 2. Segment Boundaries

How should the app think about transitions?

Examples:
- stop light while driving: still same segment
- coffee break during a hike: pause within segment or separate segment
- switching from drive to walk: definitely separate segment

Why this matters:
- Segment boundaries are central to both UX and editing.

**JF Note**
The examples you gave are correct. I'd say, a pause (perhaps with some exceptions) followed by the same activity as before should be considered one activity with pause events. But I can think of scenarios where I'd want to group together segments into one sherable activity. For exampe, I will want to share the aggregated route that I rode the entire day. possibly with or without some of the hiking activities. Another exampe would be a triathalong which has 3 different segments of different activity type.
**End JF Note**

Updated conclusion:
- This strongly suggests two layers above raw samples:
- segments as the primary detected units
- collections or sessions as user-meaningful groupings of segments
- That distinction is important because "what happened continuously" and "what I want to treat as one shareable outing" are not always the same thing.

### 3. Review Burden

How often are you willing to review uncertain segments?

Possible stances:
- only exceptional cases
- daily quick review
- detailed curation for important activities only

Why this matters:
- It determines how aggressive the app can be about asking for confirmation.

**JF Note**
Obviously this will change with time. I'm willing to review even several times per day and fix as needed. Hopefully, over time, the will be less fixing needed. 

This is something we'll need to fine tune.
**End JF Note**

Updated conclusion:
- Early versions can lean more heavily on review because you are willing to curate.
- That is useful for product development because it gives room to iterate on heuristics before optimizing for low-touch operation.

### 4. "Enough Data for Reclassification"

What does "enough" mean in practice?

Examples:
- enough to tell run vs hike later
- enough to distinguish car vs motorcycle
- enough to compute new summaries after a segment split

Why this matters:
- This is the real retention requirement, more than generic "keep some raw data."

**JF Note**
 - enough so if I manually re-clasify from a ride to a run, to the extent that entails needing different data attributes, we do keep it around (e.g. heart rate). In fact, it may be an offroad ride that does qualify as a physical activity. We should probably capture heart rate whenever above some threshold. It shoud be vieweable on the timeline along with activity info 
 - and sure, also enough to compute new summaries after a segment split.
**End JF Note**

Updated conclusion:
- Health signals should not be tied too narrowly to an initial activity label.
- Some metrics such as heart rate may deserve capture and retention based on physiological significance, not only on activity type.
- This starts to point toward overlays: movement segment plus health intensity, rather than movement and health being kept in separate conceptual worlds.

### 5. Manual Hints Before an Activity

How much do you want the app to accept an upfront hint from you?

Examples:
- no hints, fully passive
- optional hint like "I'm starting a ride"
- strong manual mode where the app should trust the declared activity unless evidence strongly contradicts it

Why this matters:
- This can reduce inference errors for the activities you care about most.

**JF Note**
All of the above. Ideally it should be fully passive. But the app should also trust the declared activity as long as the observed parameters seem at all consistent with the hint
**End JF Note**

Updated conclusion:
- Manual hints should behave like strong priors, not absolute commands.
- This is a good compromise between passive operation and practical accuracy for the activities you care about most.

## Current Synthesis

The product shape is getting clearer.

### 1. Core Recording Unit

The app should probably think in terms of:
- samples
- segments
- collections

Where:
- samples are the underlying observations
- segments are inferred continuous activities with pauses and confidence
- collections are higher-level user-meaningful groupings such as "Saturday ride", "travel day", or "triathlon"

This helps reconcile several competing needs:
- accurate automatic detection
- clean editing
- meaningful sharing
- future summaries

### 2. Classification Model

The system should likely separate:
- displayed class
- candidate subtypes
- confidence
- supporting evidence

That makes it possible to:
- start with broad visible labels
- refine later without redesigning everything
- expose more detail only when confidence is high enough

### 3. Retention Model

Retention is now looking less like:
- raw data vs no raw data

And more like:
- what evidence must survive so future reinterpretation remains possible

That includes:
- route shape
- time structure
- pause structure
- quality flags
- health overlays such as heart rate when relevant

### 4. Health Is Becoming an Overlay, Not a Separate Module

Your note about off-road riding and heart rate is important.

It suggests the app should avoid a simplistic model like:
- vehicle activity means no health data needed
- run means health data needed

A better model may be:
- movement/activity classification
- physiological intensity overlay

That could support cases like:
- strenuous hike
- intense ride
- easy walk
- poor sleep affecting next-day exertion

### 5. Sharing May Need Its Own Abstraction

Sharing probably should not operate directly on raw detected segments.

You may want to share:
- one segment
- several segments combined
- a whole day
- a route with some segments hidden
- a multi-sport event as one item

That implies the shareable object may be a curated export or a user-defined collection, not just a segment ID.

## Additional Questions Raised By Your Latest Notes

### 1. Collections vs Segments

Should the app let you explicitly group segments into a named collection?

Examples:
- "Saturday Motorcycle Ride"
- "Travel to New York"
- "Triathlon Race Day"

Why this matters:
- It may become the cleanest answer to sharing, storytelling, and summarization without corrupting the automatically detected segment structure.

**JF Note**
Yes, absolutely, that's the idea.
**End JF Note**

Updated conclusion:
- Collections should be treated as explicit user-level objects, not as accidental byproducts of segment detection.
- This gives the product a clean separation between automatic reconstruction and human storytelling/sharing.

### 2. Health Overlay Scope

How broadly should health data be retained and surfaced?

Examples:
- only for clearly physical activities
- whenever the watch records meaningful physiological changes
- always, but at different resolutions

Why this matters:
- This affects both retention and UI design.

**JF Note**
- whenever the watch records meaningful physiological changes
- and also periodically as appropriate for each attribute. That way, we establish a base line to identify outliging reads and also to see trends over time.
**End JF Note**

Updated conclusion:
- Health retention should combine event-driven capture with periodic baseline capture.
- That supports both segment interpretation and longer-term trend detection.
- This may become one of the product's more distinctive strengths if done cleanly.

### 3. Timeline Density

What should the timeline show by default?

Options to think about:
- every detected segment
- only meaningful or non-trivial segments
- segments plus important overlays like elevated heart rate, poor GPS quality, and sleep

Why this matters:
- A timeline that is too dense may become noise.
- A timeline that is too sparse may lose the "black box" feeling.

**JF Note**
- For a start, segments plus important overlays like elevated heart rate, poor GPS quality, and sleep
- We'll fine tune this overtime.
- The user can also filter the timeline if it is too noisy.
**End JF Note**

Updated conclusion:
- The default timeline should be semantic and layered: activity segments first, important overlays second.
- Filtering should be built in from the start because density will vary a lot by day and by user preference.

### 4. Unknown and Mixed Activities

How comfortable are you with the app explicitly labeling a segment as:
- unknown
- mixed
- vehicle then walk
- possible water activity

Why this matters:
- Honest ambiguity may be better than false precision, but it changes the feel of the product.

**JF Note**
Very comfortable. Honest ambiguity definetely better than false precision. We'll fine tune this too.
**End JF Note**

Updated conclusion:
- Explicit ambiguity is part of the intended product voice, not just an implementation compromise.
- That is a strong and useful principle because it supports trust and review.


**JF Note**
When I say sharing I don't mean it like sending a URL to the web UI. Rather, it would be formated as appropriate for some sharing vehicle (e.g. Facebook, Whatsapp, Messages, Email, Instagram, Tictoc, etc.)
**End JF Note**

Updated conclusion:
- Sharing should be treated as export/presentation, not as shared access to the underlying record.
- That means the shareable artifact may be a rendered summary, map, video, card, or package tailored to the destination rather than a live view into the Blackbox dataset.

## Consolidated Product View

At this point, the product is taking a much clearer shape.

### What Blackbox v1 Appears To Be

Blackbox v1 appears to be:
- a local-first, always-on movement and activity journal
- driven primarily by passive sensing on iPhone and Apple Watch
- organized around semantic segments rather than raw samples
- editable at the segment level
- honest about uncertainty
- able to group segments into user-defined collections
- capable of overlaying health and quality signals on top of movement history

### What It Is Not, At Least Initially

Blackbox v1 does not appear to be:
- a generic "record every life detail" system
- a cloud-first intelligence platform
- a point-by-point manual GIS editor
- a tool that depends on the user remembering to start and stop sessions
- a web-sharing product centered on public links

### Working Conceptual Model

The current conceptual stack now looks like:
- samples
- segments
- collections
- exports

Where:
- samples are observations and short-lived support evidence
- segments are inferred activities with pauses, confidence, and quality state
- collections are user-meaningful bundles like an outing, race, travel day, or weekend trip
- exports are presentation artifacts prepared for a destination like Messages, WhatsApp, email, Strava, or social media

### Strong Product Principles Emerging

- Meaningful history matters more than exhaustive raw retention.
- Broad correct labels are better than deep wrong labels.
- Honest ambiguity is better than false precision.
- Segment-level editing is enough for v1 and is much cleaner than point editing.
- The system should preserve enough evidence to support later reinterpretation.
- Health data should be kept both as baseline context and as activity-relevant overlay.
- Sharing is a publishing/export problem, not a dataset-exposure problem.

## Remaining Questions That Still Matter

These are the questions that still feel materially important rather than merely tuneable.

### 1. Collection Semantics

How should collections be created?

Possible approaches:
- entirely manual
- suggested automatically based on time, continuity, and location
- automatic by default with manual cleanup

Why this matters:
- It changes how much the app feels like an assistant versus a recording system with optional curation.

**JF Note**
automatic by default with manual cleanup
**End JF Note**

Updated conclusion:
- Collections should likely be suggested or created automatically by default, then made easy to rename, merge, split, or trim.
- This keeps the product aligned with passive capture while still letting the user impose meaning afterward.


### 2. Export Shapes

What kinds of exports matter most?

Examples:
- static route card with stats
- story-like timeline for a whole day
- animated route playback
- summary package suitable for Strava-style posting
- private archive export

Why this matters:
- Export needs affect what derived data and media assets the app should be able to generate.

**JF Note**
All of the above and possibly more.
**End JF Note**

Updated conclusion:
- Export should be treated as a flexible output layer, not as a single feature.
- The product should assume multiple export shapes will matter, which supports keeping exports conceptually separate from both segments and collections.

### 3. Confidence UX

How visible should confidence be in the main UI?

Possible approaches:
- always visible on every segment
- only visible when confidence is below a threshold
- hidden by default and shown in details

Why this matters:
- Confidence is central to your product philosophy, but too much visible scoring can also create visual noise.

**JF Note**
only visible when below threshold and shown in detals if the user digs deeper
**End JF Note**

Updated conclusion:
- Confidence should be selectively visible.
- Low-confidence cases should be highlighted in the main UI, while detailed confidence breakdowns belong in drill-down views.

### 4. Quality Event Handling

What should happen when the app detects likely bad data?

Examples:
- silently mark it degraded and move on
- auto-trim obviously bad portions
- surface a review item later
- ask the user in near real time if the event is important

Why this matters:
- This affects trust, interruption level, and editing burden.

**JF Note**
- auto-trim obviously bad portions
- for less obvious, surface a review item later
**End JF Note**

Updated conclusion:
- Data quality handling should combine automatic cleanup with deferred human review.
- The rule of thumb should be: auto-fix only when confidence in the fix is high, otherwise preserve the ambiguity and surface it later.

### 5. Sleep Boundary

Do you want sleep to remain a later extension, or should the data model already make room for non-movement segments now?

Why this matters:
- This is one of the few scope decisions that could slightly affect the conceptual model early.

**JF Note**
Data model should should already allow for that to be added
**End JF Note**

Updated conclusion:
- The data model should not assume every meaningful segment is movement-based.
- Even if sleep is not part of v1 scope, the conceptual model should already allow non-movement semantic segments.

## Brainstorming Resting State

This section captures the current stable state of the brainstorming.

### Product Statement

Blackbox is shaping up as a local-first iPhone and Apple Watch app that continuously and passively records meaningful movement and physiological context, turns it into editable semantic segments, groups those segments into user-meaningful collections, preserves enough supporting evidence to allow later reinterpretation, and exports curated presentations for sharing.

### Default Product Behaviors

Current default assumptions:
- passive sensing is the default mode
- manual hints are optional strong priors
- broad visible activity classes are enough to start
- ambiguity is surfaced rather than hidden
- low-confidence segments are highlighted
- obviously bad data can be auto-trimmed
- less obvious quality issues become review items
- collections are created or suggested automatically, then cleaned up manually if needed
- exports are rendered artifacts tailored to destinations, not links into the underlying dataset

### Stable Structural Model

The current structural model appears to be:
- samples
- segments
- collections
- exports

And with orthogonal overlays for:
- confidence
- quality state
- health/physiological context
- user edits and annotations

This model now seems flexible enough to support:
- broad taxonomy now and deeper taxonomy later
- movement-focused v1 with sleep added later
- private single-user use now and potential multi-user evolution later
- multiple sharing formats without entangling them with the core activity model

### What Seems Decided Enough For Now

- v1 focus is movement/activity journaling, not full-spectrum lifelogging
- the app should run passively in the background
- the unit of user interaction is mostly the segment, not the raw point
- collections are real product objects
- health should be retained both for baseline and for meaningful overlays
- cloud is secondary early on
- the data model should leave room for non-movement segments in the future

### What Still Seems Open But No Longer Blocking

These still need later refinement, but they no longer feel like core conceptual blockers:
- exact activity taxonomy
- exact review cadence
- exact export formats and templates
- exact battery policy presets
- exact timeline filtering rules
- exact heuristics for segment boundaries and grouping

## Suggested Next Brainstorming Modes

If and when you want to continue, the most natural next brainstorming branches seem to be:
- activity inference realism: what can actually be detected reliably with iPhone + Apple Watch signals
- data model shaping: what the entities and relationships should roughly look like without turning it into implementation yet
- UI concepting: what the timeline, segment detail, review queue, collection view, and export flow should feel like
- retention and sync policy: what should stay local, what should upload, and for how long

Branch documents:
- Activity inference realism: [02-activity-inference.md](/Users/judd/DevProjects/Blackbox/docs/brainstorming/02-activity-inference.md)
