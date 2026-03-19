# Blackbox Brainstorming Synthesis

This document synthesizes the current brainstorming into one coherent product view.

It is not yet a plan, specification, or architecture document.

## Product Summary

Blackbox is a local-first iPhone and Apple Watch app that passively records meaningful movement and physiological context, turns that into editable semantic segments, groups segments into user-meaningful collections, preserves enough supporting evidence to allow later user-driven reinterpretation, and produces curated exports for sharing.

The product is intended to feel like a personal black box:
- always on
- usually passive
- trustworthy
- honest about uncertainty
- useful both as a historical record and as a tool for later curation

## What Blackbox Is

Blackbox is currently best understood as:
- an always-on movement and activity journal
- a semantic timeline rather than a raw sensor dashboard
- a local-first recorder with cloud as secondary early on
- a product built around segment-level meaning, not point-level editing
- a system that surfaces ambiguity rather than hiding it
- a recorder that can later turn history into curated, shareable artifacts

## What Blackbox Is Not

At least in v1, Blackbox is not:
- a generic "record every detail of life" product
- a cloud-first intelligence platform
- a manual GIS editor
- a traditional workout tracker that depends on starting and stopping sessions
- a link-sharing or public-feed product

## Product Scope

### v1 Focus

The current v1 focus is:
- passive movement/activity journaling
- timeline reconstruction
- semantic segment detection
- segment correction and curation
- collection creation
- export-oriented sharing

### Later Expansion

Likely later expansions include:
- sleep as another passive segment type
- richer health overlays and trends
- broader health-related feeds such as weight, blood pressure, body measurements, VO2 max, BMI, and similar historical metrics from Health or other sources
- deeper activity taxonomy
- web access
- Android support
- Garmin and other device integrations
- multi-user cloud architecture

**JF Note**
For later expansion, add:
- other health related data feeds such as weight, blood-preasure, Body measurments, etc. Pulling from the Healt app or other sources. The point is, this is part of the blackbox vision. I may want to look back in a couple of years and see how my weight or VO-Max or BMI fluctuated over time.
**End JF Note**

Updated conclusion:
- The longer-term Blackbox vision is broader than movement alone.
- Over time, it should become a more general personal-history system that can include longitudinal health metrics, not just activity-linked sensor data.

## Core Product Principles

- Meaningful history matters more than exhaustive raw retention.
- Broad correct labels are better than deep wrong labels.
- Honest ambiguity is better than false precision.
- The app should work passively by default.
- The primary user-facing unit is the segment.
- Collections are separate from segments and represent user-authored meaning.
- Health is an important overlay, not a separate world.
- Sharing is export/publishing, not exposing the underlying dataset.
- The system should preserve both original inference and later user edits.

## Core Conceptual Model

The conceptual stack is currently:
- observations
- segments
- collections
- exports

With orthogonal overlays for:
- confidence
- quality state
- health context
- annotations
- edit history
- review state

### Observations

Observations are captured data points and support signals.

Examples:
- location fixes
- motion readings
- speed/elevation samples
- heart rate samples
- battery/connectivity snapshots

They mainly exist to support inference, reprocessing within a limited scope, and derived summaries.

### Segments

Segments are the core user-facing units.

A segment represents a continuous or near-continuous meaningful activity period such as:
- walking
- running
- cycling
- vehicle travel
- flight
- water activity
- unknown / mixed / uncertain

Segments have:
- time bounds
- interpretation
- summary data
- quality state
- optional pause events
- annotations
- edit history

### Collections

Collections are user-meaningful groupings of one or more segments.

Examples:
- Saturday ride
- travel day
- triathlon
- weekend outing

Collections are distinct from segments:
- segments are what the system detected
- collections are how the user chooses to organize, remember, and share meaning

Collections may contain:
- segments
- notes/media
- nested sub-collections

### Exports

Exports are curated presentation artifacts created from segments or collections.

Examples:
- route card
- stats summary
- story-like timeline
- animated route playback
- archive package

Exports may be durable saved artifacts, not just transient renders.

## Activity Inference Direction

### Recommended Visible v1 Classes

- stationary
- walking
- running
- cycling
- vehicle
- flight
- water activity
- unknown / mixed / uncertain

### Explicitly Deferred or Softened

- hiking should fold into walking unless confidence is strong
- driving/train/bus/motorcycle should stay under vehicle for now
- swimming/rowing/sailing/speed boat should stay under water activity for now
- sleep should be treated later as a separate passive segment type

### Inference Philosophy

The classifier should be conservative:
- prefer broad correct labels
- keep ambiguity first-class
- only surface narrower labels when confidence is strong enough

## Data And Retention Philosophy

### Retention Principle

The product does not aim to keep all raw data forever.

It aims to:
- keep dense raw support data only for a limited window
- retain selected support evidence when needed for future understanding or recategorization
- keep semantic history durably

### Durable Data

The following should generally be durable:
- segment summaries
- collections
- saved exports
- user annotations
- edit history
- review history or structured review state

### Historical Integrity

A major product principle established during brainstorming:
- user edits should be preserved
- later improvements in heuristics should not silently rewrite historical records
- long-settled activities do not need to retain support baggage indefinitely just to enable future re-inference

This makes Blackbox feel more like a recorder/journal than a self-rewriting analytics engine.

**JF Note**
I wouldn't neccessarily save the original inference. If that's an outcome of the implementation then so be it. My point was rather that new capabilities don't need to be applied to old activities whether reviwed or not. We don't need to keep around a baggage of supporting data just so we can re-apply newer inference rules for old activity. Once the activity has settled for a while (A week or a month) even if confidence is low, we can get rid of the baggage. Does that make sense? IF not, please point out the gaps in my thinking about this.
**End JF Note**

Updated conclusion:
- This makes sense and is a better statement of the actual product intent.
- The key principle is not "preserve every old inference artifact forever."
- The key principle is "do not silently reinterpret settled history later just because the classifier improved."
- That means the product can safely compact or discard old support baggage after a settling window, while still preserving the settled segment record and any user edits.


## Local vs Cloud

### Local-First

The app should remain operationally correct even when:
- offline
- on poor connectivity
- roaming
- prevented from syncing

Local storage is therefore the primary operational store, not merely a cache.

### Cloud Early On

Cloud is useful early on mainly for:
- backup
- recovery
- long-term durability
- future web access
- future portability

Cloud is not currently positioned as the primary inference engine.

### Storage Direction

The storage strategy should remain open between:
- app-managed cloud backend
- user-owned cloud storage
- hybrid architecture

This should stay undecided for now.

## Sync Philosophy

### Default Sync

The likely default model is opportunistic sync:
- capture locally first
- upload when conditions are acceptable
- defer when battery/network conditions are poor

### Adaptive In-Progress Uploads

For long or important activities, the app may upload during the activity:
- opportunistically when conditions are good
- more readily as unsynced valuable data accumulates
- potentially with different behavior when in-progress sharing matters

### Network Policy

The sync model should be graduated:
- light sync can happen broadly
- heavier sync should prefer better conditions
- roaming should be conservative unless overridden

**JF Note**
Can the app figure out if the device is in data roaming?
**End JF Note**

Open technical note:
- Whether the app can reliably detect roaming status is a platform capability question that should be verified during architecture/spec work rather than assumed here.

### Battery Policy

Battery behavior should be:
- policy-driven
- user-visible
- overrideable

Likely user-facing modes:
- aggressive
- balanced
- battery-preserving

With adjustments based on:
- Low Power Mode
- battery thresholds
- charging state
- user override

## UI Direction

### Main UI Structure

The recommended UI direction is:
- timeline-first home
- adaptive cards
- collection cards in the same timeline
- segment and collection detail views
- review primarily handled through timeline filters/tags
- quick-share export flow
- settings/policies as an important secondary area

### Timeline

The timeline is the center of gravity.

It should:
- group content by day
- show segments, collections, and important overlays
- support filtering and search
- support activity, review, confidence, title, and location/area filtering
- visually tag low-confidence and needs-review items

### Segment And Collection Detail

Detail views should:
- be map-forward for movement-heavy content
- show clear stats and summaries
- surface confidence/quality only when relevant
- support split, trim, retitle, reclassify, note, collect, and export actions

### Watch Direction

The Apple Watch should:
- contribute passive background capture
- have its own activity-aware UI
- foreground the currently inferred activity
- make in-the-moment correction easy

## Review And Ambiguity Handling

Ambiguity is part of the intended product voice.

That means the app should explicitly support:
- unknown
- mixed
- possible subtype
- low confidence
- needs review

The UI should not over-alarm, but it should make uncertain or suspicious items easy to find and fix.

## Sharing And Export

Sharing is not primarily about giving access to the raw Blackbox record.

It is about producing destination-appropriate artifacts for:
- Messages
- WhatsApp
- Email
- Facebook
- Instagram
- TikTok
- later Strava-style destinations

Exports should feel like quick sharing with light customization, including selectable attributes when relevant.

## Health And Sensitive Data

### Health

Health data should be retained and shown:
- when physiologically meaningful changes occur
- and also periodically enough to establish baselines and trends

This supports both:
- interpreting activity segments
- broader context over time

### Sensitive Categories

If the product ever supports highly sensitive categories:
- detection should be opt-in
- storage should be opt-in
- timeline visibility should be separately opt-in
- sharing should never expose such categories by accident

## Stable Product Identity

The current brainstorming points to a fairly consistent identity:

Blackbox is a passive, local-first, uncertainty-aware personal activity recorder that organizes life into semantic segments and collections, preserves history with integrity, and lets the user curate and export meaningful slices of that history.

## What Still Remains Open

The major conceptual questions are now substantially answered.

What remains open is mostly later refinement:
- exact heuristics
- exact schema design
- exact UI layouts and visual language
- exact sync thresholds and retention windows
- exact storage backend choice
- exact export templates and formats

## Natural Next Step

The natural next step, if you want to move beyond brainstorming, is one of:
- a rough architecture document
- a v1 scope/spec document
- a phased implementation plan
