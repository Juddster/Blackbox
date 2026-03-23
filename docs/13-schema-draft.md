# Blackbox Schema Draft

This document proposes a practical persisted-model draft for Blackbox.

It is not yet tied to a specific database engine, ORM, or API contract.

Its purpose is to define:
- what records exist
- what the important fields are
- how records relate to each other
- what data is temporary versus durable
- what data is likely local-only versus synced

## Scope Basis

This draft assumes:
- [09-v1-requirements-spec.md](/Users/judd/DevProjects/Blackbox/docs/09-v1-requirements-spec.md)
- [10-domain-model-draft.md](/Users/judd/DevProjects/Blackbox/docs/10-domain-model-draft.md)
- [12-implementation-phases.md](/Users/judd/DevProjects/Blackbox/docs/12-implementation-phases.md)

## Schema Design Principles

- Keep the durable semantic history simple.
- Keep temporary support data separate from durable user-facing history.
- Prefer current effective state over rich historical versioning in v1.
- Support direct mutation for user edits where practical.
- Preserve enough metadata for sync correctness and UI consistency.
- Keep room for future multi-user storage without making v1 heavy.

## Record Groups

The schema naturally breaks into four groups:
- support-data records
- semantic-history records
- workflow/policy records
- export/sync records

## 1. Support-Data Records

These records are mainly for capture, inference, and short/medium-term replay.

### 1.1 ObservationRecord

### Purpose

Stores a captured timestamped input datum.

### Core Fields

- `id`
- `timestamp`
- `source_device`
  - `iphone`
  - `watch`
- `source_type`
  - location
  - motion
  - pedometer
  - heart_rate
  - device_state
  - connectivity
  - other future source
- `payload`
- `quality_hint`
- `ingested_at`

### Durability

- mostly temporary
- may be retained longer in development datasets or selected replay cases

### Sync Expectation

- generally not part of durable semantic sync by default
- selected support data may be synced when justified

### 1.2 SupportEvidenceRecord

### Purpose

Stores a retained support artifact derived from raw observations when the raw stream no longer needs to survive.

### Examples

- simplified route geometry
- speed profile summary
- elevation profile summary
- selected heart-rate series
- confidence-supporting derived features

### Core Fields

- `id`
- `segment_id` or provisional segment reference
- `evidence_type`
- `time_range_start`
- `time_range_end`
- `payload`
- `retention_reason`

### Durability

- medium-term or durable depending on product value

### Sync Expectation

- selectively synced when needed for settled segment understanding

## 2. Semantic-History Records

These are the records the product is fundamentally about.

### 2.1 SegmentRecord

### Purpose

Stores a durable semantic activity segment.

### Core Fields

- `id`
- `start_time`
- `end_time`
- `lifecycle_state`
  - active
  - settled
  - deleted
- `origin_type`
  - system
  - user_created
  - merged
  - split_result
- `primary_device_hint`
- `created_at`
- `updated_at`

### Notes

This should be the central durable record in the schema.

### Durability

- durable

### Sync Expectation

- yes

### 2.2 SegmentInterpretationRecord

### Purpose

Stores the current effective interpretation of a segment.

### Core Fields

- `segment_id`
- `visible_class`
- `user_selected_class` nullable
- `confidence`
- `ambiguity_state`
- `needs_review`
- `interpretation_origin`
  - system
  - user
  - mixed
- `updated_at`

### Notes

This is intentionally current-state oriented.
v1 should not overbuild interpretation history.

### Durability

- durable

### Sync Expectation

- yes

### 2.3 SegmentSummaryRecord

### Purpose

Stores current summary values for a segment.

### Core Fields

- `segment_id`
- `duration_seconds`
- `distance_meters` nullable
- `elevation_gain_meters` nullable
- `avg_speed` nullable
- `max_speed` nullable
- `pause_count`
- `route_summary_payload` nullable
- `heart_rate_summary_payload` nullable
- `summary_version_hint`
- `updated_at`

### Durability

- durable

### Sync Expectation

- yes

### 2.4 PauseEventRecord

### Purpose

Stores a pause/interruption inside a segment.

### Core Fields

- `id`
- `segment_id`
- `start_time`
- `end_time`
- `pause_type` nullable
- `confidence` nullable

### Durability

- durable if it materially affects summaries or UI

### Sync Expectation

- yes if retained

### 2.5 QualityRecord

### Purpose

Stores quality/trustworthiness state for a segment or a sub-interval.

### Core Fields

- `id`
- `segment_id`
- `interval_start` nullable
- `interval_end` nullable
- `quality_state`
  - trusted
  - degraded
  - implausible
  - auto_trimmed
  - suspicious
- `details_payload` nullable
- `created_at`

### Durability

- durable in compact form

### Sync Expectation

- yes

### 2.6 AnnotationRecord

### Purpose

Stores user-authored annotations for a segment or collection.

### Core Fields

- `id`
- `target_type`
  - segment
  - collection
- `target_id`
- `annotation_type`
  - title
  - note
  - tag
  - media
- `payload`
- `created_at`
- `updated_at`

### Durability

- durable

### Sync Expectation

- yes

### 2.7 CollectionRecord

### Purpose

Stores a user-defined grouping of distinct segments.

### Core Fields

- `id`
- `title`
- `summary_payload` nullable
- `created_at`
- `updated_at`

### Durability

- durable

### Sync Expectation

- yes

### 2.8 CollectionSegmentRecord

### Purpose

Stores membership and ordering between collections and segments.

### Core Fields

- `collection_id`
- `segment_id`
- `sort_order`
- `added_at`

### Durability

- durable

### Sync Expectation

- yes

## 3. Workflow / Policy Records

### 3.1 ReviewItemRecord

### Purpose

Stores active reviewable issues.

### Core Fields

- `id`
- `target_type`
  - segment
  - segment_interval
- `target_id`
- `interval_start` nullable
- `interval_end` nullable
- `review_type`
  - low_confidence
  - suspicious_quality
  - ambiguous_classification
  - other
- `status`
  - open
  - dismissed
  - resolved
- `created_at`
- `resolved_at` nullable

### Durability

- active state durable enough for workflow
- long-term permanent history not required in rich form

### Sync Expectation

- yes while active
- compact retention after resolution

### 3.2 PolicyStateRecord

### Purpose

Stores current app policy settings relevant to behavior.

### Core Fields

- `id`
- `battery_mode`
- `sync_mode`
- `low_power_behavior`
- `review_notification_mode`
- `updated_at`

### Durability

- durable

### Sync Expectation

- likely local-first, sync optional depending on account/device strategy

## 4. Export / Sync Records

### 4.1 ExportArtifactRecord

### Purpose

Stores saved exports.

### Core Fields

- `id`
- `source_type`
  - segment
  - collection
- `source_id`
- `export_type`
- `title` nullable
- `included_attributes_payload`
- `render_metadata_payload`
- `stored_payload_ref` nullable
- `inline_payload` nullable
- `created_at`

### Durability

- durable when saved

### Sync Expectation

- yes

### 4.2 SyncCursorRecord

### Purpose

Stores sync bookkeeping state.

### Core Fields

- `record_group`
- `last_synced_at` nullable
- `last_attempted_at` nullable
- `cursor_payload` nullable
- `error_state` nullable

### Durability

- durable operational metadata

### Sync Expectation

- local operational state

### 4.3 DeviceRecord

### Purpose

Represents a participating device in the local/cloud system.

### Core Fields

- `id`
- `device_type`
  - iphone
  - watch
- `display_name`
- `created_at`
- `last_seen_at`

### Durability

- durable

### Sync Expectation

- yes if device-aware sync/reconciliation is implemented

## Suggested Relationships

### Core

- `SegmentRecord` 1:1 `SegmentInterpretationRecord`
- `SegmentRecord` 1:1 `SegmentSummaryRecord`
- `SegmentRecord` 1:N `PauseEventRecord`
- `SegmentRecord` 1:N `QualityRecord`
- `SegmentRecord` 1:N `AnnotationRecord`
- `SegmentRecord` 1:N `ReviewItemRecord`

### Collections

- `CollectionRecord` N:M `SegmentRecord` via `CollectionSegmentRecord`
- `CollectionRecord` 1:N `AnnotationRecord`

### Support Data

- `ObservationRecord` may map indirectly to `SegmentRecord`
- `SupportEvidenceRecord` may reference `SegmentRecord`

### Exports

- `ExportArtifactRecord` references either `SegmentRecord` or `CollectionRecord`

## Records Likely To Change Frequently

- `ObservationRecord`
- `SegmentInterpretationRecord`
- `SegmentSummaryRecord`
- `ReviewItemRecord`
- `SyncCursorRecord`

## Records That Should Feel Stable

- `SegmentRecord`
- `CollectionRecord`
- `CollectionSegmentRecord`
- `AnnotationRecord`
- `ExportArtifactRecord`

## Split / Merge Handling

### Split

Likely pragmatic v1 rule:
- original segment may be replaced by new child segments
- summaries and collection membership must be updated coherently

### Merge

Likely pragmatic v1 rule:
- merged result becomes the effective segment going forward
- original segments may be removed from active history

The key requirement is consistency, not perfect historical version tracking.

## Local vs Synced View

### Mostly Local

- dense `ObservationRecord`
- transient operational replay data
- sync cursors and local diagnostics

### Synced Durable Semantic History

- segments
- interpretations
- summaries
- quality state
- annotations
- collections
- collection membership
- active review state
- exports

### Selectively Synced

- support evidence
- some resolved review metadata
- some device records

## Suggested v1 Simplifications

- Keep one current interpretation per segment.
- Keep one current summary per segment.
- Keep review items simple and mostly active-state-oriented.
- Keep edit consequences applied directly to current records rather than introducing heavy version history.
- Keep collection media/notes as a later extension if they complicate the base schema.

## Open Schema Questions

### 1. Segment Replacement Strategy

For split/merge operations, should the old segment rows:
- be deleted from active history
- be retained with a superseded state
- vary by operation

**JF Note**
Deleted
**End JF Note**

Updated conclusion:
- For v1, old segment rows can be deleted from active history after split/merge operations.
- This is the simplest rule and fits the current-state-oriented model.
- The implementation still needs to update related records coherently, especially collections, exports, and review state.

### 2. Export Payload Storage

Should saved exports store:
- the fully rendered payload
- a renderable recipe/reference set
- both

**JF Note**
both
**End JF Note**

Updated conclusion:
- Saved exports should keep both:
- enough rendered payload to re-share or view the same artifact directly
- enough metadata/reference context to understand what the export came from

### 3. SupportEvidence Scope

Should `SupportEvidenceRecord` be:
- a real persisted concept in v1
- or just an implementation detail inside the observation/replay layer

**JF Note**
Well, what would it be useful for after a segment has been settled (meaning, to the extent there was any uncertainty or ambiguity, the user has reviewed and made a decision)?

Also, just to make sure, does this schema allows for a live action to be shared? Here's what I have in mind. I would like to be able to share a slugged link to whomever where they can follow me live on a map. I could revoke that link or stop it. If revoked, than there is no access to any content any longer. If I stop sharing to that link, the content will stop updating but anyone with the link can still view whatever I shared. I could add comments and photos as I go or after relating to specific locations (or not) and turn it into a live trip report that can also remain in the records.
**End JF Note**

Updated conclusion:
- After a segment is truly settled, `SupportEvidenceRecord` should usually no longer survive as a first-class durable record unless it still serves a clear user-visible purpose.
- The simplest v1 rule is:
- keep support evidence mainly as a medium-term or development/replay concern
- compact or discard it once the semantic segment is settled and no longer needs the baggage

Updated conclusion on live sharing:
- The current v1 schema does not explicitly model live share links or evolving trip reports.
- It can support saved exports, but live share links and ongoing narrative updates introduce a distinct concept that should be modeled separately.

## Future Extension: Live Sharing And Trip Reports

This is not currently a v1 requirement, but the idea is coherent and the schema should not block it later.

### Candidate LiveShareSessionRecord

Purpose:
- represent a revocable live share link for an ongoing activity or trip-like record

Potential fields:
- `id`
- `share_token` or slug
- `source_type`
  - segment
  - collection
  - live_trip
- `source_id`
- `status`
  - active
  - stopped
  - revoked
- `created_at`
- `stopped_at` nullable
- `revoked_at` nullable

### Candidate LiveShareUpdateRecord

Purpose:
- represent ongoing updates tied to a live share session

Potential fields:
- `id`
- `live_share_session_id`
- `timestamp`
- `location_payload` nullable
- `comment_payload` nullable
- `media_ref` nullable

### Candidate TripReportRecord

Purpose:
- represent a durable trip-report-like narrative that can outlive the live session

Potential relationship:
- may originate from a live share session
- may later become or produce an export artifact

Schema implication:
- the current v1 schema is not enough by itself to support live link sharing cleanly
- but it does not conflict with adding these records later
