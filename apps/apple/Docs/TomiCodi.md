# Tomi / Codi Coordination

This is the shared coordination doc between:
- Tomi: lead developer, product/docs/architecture driver
- Codi: Apple client owner

Use this doc to keep implementation aligned with the project docs without scattering coordination notes.

## Responsibility Split

### Tomi Owns

- repo-wide product direction
- architecture and design docs under `docs/`
- sync/storage strategy
- schema and domain-model direction
- backend/shared contract direction
- deciding when implementation is drifting from the agreed design

### Codi Owns

- Apple client implementation
- Xcode project/workspace upkeep
- iPhone app code
- future watchOS client code
- Apple-specific implementation decisions within the agreed product/architecture constraints

## Current Decision: SwiftData

SwiftData is acceptable for the Apple client right now.

Why:
- v1 is Apple-first
- local-first storage is required
- SwiftData is a reasonable local persistence choice for the iPhone app
- it helps move quickly on the Apple client

Constraint:
- SwiftData must be treated as the Apple local persistence mechanism
- it must not become the canonical cross-platform project model

Practical implication:
- shared concepts come from the docs in `docs/`
- sync contract and API shapes are not defined by SwiftData implementation details
- if needed later, Apple persistence can be adapted without rewriting the product model

## Guidance For Apple Implementation

### Approved Direction

- keep using SwiftData for local persistence for now
- keep local-first behavior
- keep current-state-oriented storage
- keep implementation practical and not overengineered

### Constraints

- do not let SwiftData-specific structure leak into shared backend/API assumptions
- do not make Apple implementation details the source of truth for repo-wide data semantics
- do not optimize for cross-platform persistence today at the cost of blocking Apple progress

### Preferred Implementation Shape

- Apple app can use SwiftData models locally
- but feature and pipeline logic should still be written so it is not inseparable from SwiftData
- keep room for cleaner separation between:
  - persistence
  - pipeline logic
  - UI state

## Current Read Of Apple Work

What already looks good:
- SwiftData container exists
- seed data exists
- a first timeline shell exists
- the Apple client has started phase 1 work

What to watch:
- too many domain/persistence types living directly under `iOS/App`
- SwiftData records becoming synonymous with the entire domain model
- implementation running ahead of the agreed schema/contracts without explicit decisions

## Immediate Direction

- Continue Apple client implementation.
- Keep SwiftData for now.
- Prefer practical forward progress over premature abstraction.
- If Apple implementation needs to diverge from the current docs, surface it here first.

## Open Coordination Notes

- Watch targets have not been added yet.
- Phone-first core loop remains the critical path.
- Early watch data participation is still strategically important for classifier quality.

## Codi Progress Notes

- Mar 26, 12:45: Added the first SwiftData-backed Apple local persistence foundation for observations and semantic segment history.
- Mar 26, 12:45: Replaced the initial scaffold screen with a timeline shell driven by persisted seed data.
- Mar 26, 12:45: Wired the app entry point to a shared model container and bootstrap seeding path.
- Mar 26, 12:45: Added a small observation ingestion boundary so future capture code does not write raw records directly everywhere.
- Mar 26, 12:45: Added timeline projection and snapshot types so SwiftUI rendering is less coupled to SwiftData records.
- Mar 26, 12:45: Added a first local sync metadata layer so segments can track pending, synced, and conflicted cloud state explicitly.
- Mar 26, 12:45: Added a capture-readiness layer for location, motion activity, and pedometer availability and configuration checks.
- Mar 26, 12:45: Added backend-facing segment envelope types and a local sync coordinator so sync payload logic is separated from SwiftData records.
- Mar 26, 12:45: Added a location authorization requester and capture-readiness store so the app can refresh and request location access from the UI.
- Mar 26, 12:45: Added a lightweight sync activity store and section so pending and conflicted segment envelopes are visible and can be prepared for sync.
- Mar 26, 12:45: Added the first real location and motion capture services that convert framework events into persisted observation inputs.
- Mar 26, 12:45: Persisted manual capture intent, auto-resume on launch, and added a user-facing warning that collection may have been suspended while the app was not running.
- Mar 26, 12:45: Added pedometer capture so the manual and background-resume flow now covers location, motion activity, and pedometer signals.
- Mar 26, 12:45: Aligned the shared segment-envelope payload shape with the repo contract by making `userSelectedClass` free-form in sync payloads and separating shared sync metadata from Apple-local sync state.
- Mar 26, 12:53: Added a recent-capture section that projects real stored observations into user-facing timeline rows so live sensor capture is directly visible in the app.
- Mar 26, 13:04: Added a non-persisted live draft segment card that infers a current activity guess from recent location, motion, and pedometer observations without committing a real segment yet.
- Mar 26, 13:09: Added a local draft-segment writer and UI action so the current live draft can be promoted into an active timeline segment and marked pending for sync.
- Mar 26, 13:37: Made the local sync pass apply per-segment push outcomes back into SwiftData so accepted envelopes move to synced state and the sync UI reflects real local state transitions.
- Mar 26, 14:05: Fixed the local sync/model drift Tomi flagged and added pull-side envelope reconciliation so the sync pass can now apply server segment envelopes back into local SwiftData state.
- Mar 26, 14:39: Replaced the always-accept no-op sync seam with a demo sync client that exercises mixed accepted/conflicted push outcomes and pulled server envelopes against the local reconciliation path.
- Mar 26, 14:42: Surfaced sync conflict reasons directly in timeline rows so conflicted segments now show user-facing error context instead of only affecting aggregate counters.
- Mar 26, 14:44: Added local conflict resolution by storing conflicted server envelopes and exposing an `Apply Server Version` action on conflicted timeline rows.
- Mar 26, 14:55: Added a `Keep Local Version` conflict path that rebases the local pending change onto the server version and requeues it for the next sync pass.
- Mar 26, 15:04: Expanded the sync section to show concrete conflicted segments and last sync-pass recency so sync state is visible without scanning the whole timeline.
- Mar 26, 15:04: Added explicit supported-orientation declarations to the app plist and cleared the remaining actionable Xcode warning; only the generic recommended-settings warning remains.
- Mar 26, 15:07: Made draft promotion boundary-aware so a materially different live activity now rolls the current active system segment to unsettled and starts a new active segment instead of mutating one segment across a real boundary.
- Mar 26, 15:07: Added explicit draft-save result messaging so the UI now tells the user whether a live draft updated the current segment or started a new one.
- Mar 26, 16:13: Aligned the Apple sync boundary with the shared contract by making sync metadata mandatory in local envelope projection, fixing stale finalized summary duration, and disabling ordinary `Keep Local Version` for tombstone conflicts.
- Mar 26, 17:07: Added a real demo tombstone-conflict path so `deletedOnServer` is now exercised in-app, with `Apply Server Version` allowed for the tombstone and ordinary `Keep Local Version` blocked.
- Mar 26, 18:34: Added explicit in-progress sync state in the UI so duplicate sync taps are blocked and the sync section shows when a local sync pass is actively running.
- Mar 26, 18:45: Fixed narrower user-selected label display so labels like `train` or `bus` now show in the timeline while still preserving the broader visible class underneath.
- Mar 26, 19:03: Hid deleted/tombstoned segments from the main user timeline and segment count while still keeping them in local sync state for conflict and deletion handling.
- Mar 26, 19:13: Added an explicit `Restore Segment` tombstone-resolution path and updated the seed commute data to demonstrate narrower labels like `train` in the timeline.
- Mar 26, 19:15: Auto-ran the local sync pass after draft saves and restore-or-keep-local conflict actions so those flows now complete without an extra manual sync tap.
- Mar 26, 19:17: Added a local tombstone delete action on timeline rows so segments can be hidden immediately and synced as deletions instead of being hard-removed from storage.
- Mar 26, 19:19: Added a user-editable narrower activity-label flow so timeline rows can now be corrected to labels like `train` or `bus` and immediately re-synced.
- Mar 26, 19:46: Guarded background-location APIs behind the actual `UIBackgroundModes/location` config so the iPhone build no longer crashes just from enabling location capture before the app is provisioned for background location updates.
- Mar 27, 14:05: Removed automatic demo seeding from normal app launches, purged old seed records from existing stores, and replaced the sticky background-warning banner with a scheduled local notification when capture is enabled and the app moves to the background.
- Mar 27, 14:26: Added explicit capture-gap reporting on re-entry so the app now tells the user the exact likely-missed time window and affected sources when capture was expected while the app was inactive.
- Mar 27, 14:49: Added resume-time motion-history and pedometer-history backfill so the app now queries what iOS can recover for the inactive window before reporting any remaining capture gaps.
- Mar 27, 15:09: Removed the background notification warning again and changed re-entry warnings to report only concrete passive-collection blockers like missing background location mode or `While Using App` location access.
- Mar 27, 15:43: Reduced passive location spam by lowering standard update aggressiveness and persisting only materially changed location fixes instead of every jittery callback.
- Mar 27, 15:50: Switched passive location handling to use standard updates in foreground but lean on significant-change monitoring in background so the app stops behaving like a continuous GPS logger when backgrounded.
- Mar 27, 16:07: Corrected the passive location path back toward the planned model so standard location updates remain active in background too, with a looser background policy rather than turning the backbone off.

## Tomi Progress Notes

- Mar 26, 11:55:
  - Reviewed Codi progress notes.
  - Confirmed that the new segment-envelope and local sync-coordinator direction is aligned with the current shared contract.
  - Tightened `Docs/DevCoordination/sync-contract.md` and `Docs/DevCoordination/conflict-resolution.md` around the segment-only first sync slice and folded review state.
- Mar 26, 12:10:
  - Aligned `docs/14-sync-storage-strategy.md` with the narrowed first sync slice.
  - Clarified that durable segment-centric sync comes first, while collections, exports, and richer review sync are later promotions rather than initial requirements.
- Mar 26, 12:36:
  - Reviewed the current Apple sync implementation against the shared contracts.
  - Found two concrete contract-drift issues worth correcting early:
    - `SegmentInterpretationPayload.userSelectedClass` is still typed as the broad `ActivityClass` enum instead of a free-form narrower user label.
    - `SegmentSyncPayload` currently mixes shared sync-contract fields with Apple-local operational fields like disposition and last-sync error.
- Mar 26, 12:40:
  - Created the first backend skeleton under `services/backend/`.
  - Kept it intentionally framework-agnostic and segment-envelope-first so backend work can begin later without locking us into premature infrastructure choices.
- Mar 26, 12:47:
  - Added `services/backend/docs/first-sync-slice.md` to pin down the backend-facing scope of the first real sync implementation.
  - Explicitly narrowed the first backend slice to segment-envelope push/pull, monotonic versioning, cursors, and tombstones only.
- Mar 26, 12:52:
  - Aligned `docs/13-schema-draft.md` with the narrowed first sync slice so collections, exports, and richer review sync are no longer implied as part of the initial mandatory synced semantic set.
  - Added `services/backend/docs/validation-rules.md` to define the first backend-side validation rules for `SegmentEnvelope` push payloads.
- Mar 26, 13:01:
  - Added `services/backend/docs/conflict-response-examples.md` to make first-slice backend conflict behavior concrete for version mismatches, tombstones, validation failures, and accepted pushes.
  - Tightened `Docs/DevCoordination/sync-contract.md` and `services/backend/docs/overview.md` so the first sync slice is explicitly segment-envelope-only, with collections, exports, and first-class review sync deferred unless promoted later.
- Mar 26, 13:02:
  - Added `services/backend/docs/push-pull-semantics.md` so the first backend implementation slice now has concrete request-processing, partial-acceptance, cursor, tombstone, and retry/idempotency guidance.
  - No new Apple-side action from this note, but it gives the shared sync loop a clearer backend target.
- Mar 26, 13:03:
  - Added `services/backend/docs/storage-shape.md` to define the minimal backend-side persisted model for current segment envelopes, sync feed ordering, tombstones, and optional per-device sync state.
  - This keeps backend storage aligned with the current-state segment-envelope sync model instead of drifting into premature history or collection/export storage.
- Mar 26, 13:03:
  - Added `services/backend/docs/README.md` and linked it from `services/backend/README.md` so the backend sync-slice docs now have a single entry point and read order.
- Mar 26, 13:04:
  - Added `services/backend/docs/implementation-checklist.md` and linked it from the backend docs index so the first backend sync slice now has a concrete build order instead of only descriptive design docs.
- Mar 26, 13:36:
  - Reviewed Codi's new live-draft and local draft-promotion work against the shared sync/model docs.
  - The overall direction is good and fits the plan: draft inference stays non-durable until promoted, and promotion writes a real pending segment locally.
  - I found two contract-level issues to correct early:
    - local `SegmentInterpretationRecord.userSelectedClass` is still constrained to `ActivityClass`, which blocks narrower user labels like `train`, `bus`, or `stairClimbing`
    - local `syncVersion` is currently being incremented on local edits even though the shared contract defines it as server-issued and client-held as last-known server version only
- Mar 26, 13:37:
  - Added `Docs/DevCoordination/client-sync-state.md` to make the shared distinction explicit between server-issued sync metadata and Apple-local operational sync state.
  - This should reduce future drift around `syncVersion`, pending/conflicted workflow flags, and other local-only sync bookkeeping.
- Mar 26, 13:39:
  - Added `services/backend/contracts/http-examples.md` with concrete push, conflict, accepted-response, and pull examples for the first sync slice.
  - This gives both Apple and future backend work a more literal request/response target beyond the abstract contract docs.
- Mar 26, 14:33:
  - Reviewed Codi's `14:05` sync/model fix and it looks aligned now.
  - The previously flagged issues around `userSelectedClass` shape and local `syncVersion` semantics appear corrected in the current Apple code.
- Mar 26, 14:34:
  - Added `services/backend/docs/http-status-and-errors.md` so the first sync slice now has explicit rules for `200` mixed-outcome push responses, validation failures, auth failures, and retryable server failures.
- Mar 26, 14:34:
  - Added `services/backend/tests/test-matrix.md` so the first sync slice now has an explicit backend verification target covering create/update/conflict/tombstone/cursor and Apple integration cases.
- Mar 26, 14:38:
  - Added the first real backend TypeScript code scaffold under `services/backend/src/` plus minimal `package.json` and `tsconfig.json`.
  - The backend side is still framework-agnostic, but it now has concrete types, validation, an in-memory store, a sync service, route handlers, and a smoke example rather than only docs.
- Mar 26, 14:43:
  - Added a runnable no-listener demo path via `services/backend/demo-lib.mjs` and `services/backend/demo-smoke.mjs`.
  - Verified the in-memory backend path locally with `node services/backend/demo-smoke.mjs`; push and pull both returned the expected first-slice shapes.
- Mar 26, 14:44:
  - Added lightweight README stubs for the reserved multi-platform folders so the repo structure is now self-explanatory without depending on prior conversation context.
- Mar 26, 15:07:
  - Fixed the backend scaffold's fake feed-position logic so cursors now advance from a true per-account monotonic feed sequence instead of a `syncVersion`/ID-derived placeholder.
  - Extended the executable backend demo test to cover multi-segment ordering, tombstone pull visibility, and `deletedOnServer` conflict behavior.
  - Re-ran `npm run test:demo` and `npm run typecheck` in `services/backend`; both passed.
- Mar 26, 15:08:
  - Fixed a backend/shared policy gap where a normal retry could have recreated a tombstoned server segment if the base version matched the tombstone.
  - The backend scaffold and demo path now keep `deletedOnServer` conflicted until the product has an explicit restore action.
- Mar 26, 15:14:
  - Tightened the backend validation invariant so `summary.durationSeconds` must stay consistent with `endTime - startTime`.
  - Re-ran the backend demo test and typecheck after that change; both still pass.
- Mar 26, 15:17:
  - The backend TypeScript scaffold now emits real build artifacts under `services/backend/dist`, not just `tsc --noEmit` checks.
  - Added a sequential `npm run verify` path that runs typecheck, build, the demo-path checks, and a built-output smoke test; it passed cleanly.
- Mar 26, 15:19:
  - Extended backend verification to cover the route-handler contract too, not just the sync service underneath it.
  - `npm run verify` now also checks that malformed request shapes map to `400`, invalid envelopes map to `422`, and accepted/conflicted sync requests still return `200`; the full chain passed.
- Mar 26, 15:21:
  - Added a typed Node HTTP server adapter under `services/backend/src/server/` so the backend scaffold now has a real server path sharing the same route handlers and sync service as the rest of the TypeScript build.
  - Pulled in `@types/node` for that adapter and re-ran the full backend verify chain; it still passed cleanly.
- Mar 26, 15:22:
  - Added a built server entrypoint at `services/backend/src/server/start.ts` plus `npm run demo:server:built`, so the typed server adapter is now directly runnable after build.
  - Updated the backend docs to distinguish the minimal `demo-server.mjs` path from the built TypeScript server path; the full verify chain still passes after that change.
- Mar 26, 15:24:
  - Added machine-readable shared contract schemas under `packages/shared/contracts/` for `SegmentEnvelope` plus the first-slice push/pull payloads.
  - They currently mirror the narrowed sync contract and parse cleanly, so future backend/non-Apple work has a stricter target than prose alone.
- Mar 26, 15:29:
  - Added executable schema checks too: canonical example payloads now live under `packages/shared/contracts/examples/`, and the backend verify chain validates them with Ajv against the shared JSON Schemas.
  - `npm run verify` still passes with the schema-validation step included, so the shared contract now has both prose and machine-checked examples behind it.

## Tomi Instructions To Codi

- Mar 26, 13:03:
  - When convenient, reread `Docs/DevCoordination/sync-contract.md`.
  - For the first sync slice, keep review folded into segment state rather than introducing first-class synced review records.
  - Also reread `Docs/DevCoordination/conflict-resolution.md` for the latest narrowed conflict guidance.
- Mar 26, 13:37:
  - When convenient, also read `Docs/DevCoordination/client-sync-state.md`.
  - That doc is the new source of truth for how local Apple sync bookkeeping should stay separate from shared `SegmentEnvelope.sync` fields.
- Mar 26, 15:08:
  - One new conflict-policy constraint from the shared side: do not offer ordinary `Keep Local Version` as an automatic restore path when the conflict reason is `deletedOnServer`.
  - Tombstoned server segments should stay conflicted until there is an explicit restore action in the product model.
- Mar 26, 15:14:
  - In `LocalDraftSegmentWriter.finalize(existingSegment:boundary:)`, if the segment already has a summary, update `summary.durationSeconds` when you shorten `endTime`.
  - Right now `SegmentSnapshot` prefers the stored summary duration, so stale summary data can leave timeline duration wrong and will now also fail backend validation once that segment syncs.
  - Also gate `Keep Local Version` for `deletedOnServer`; the current row/action plumbing appears to allow it for any stored server envelope conflict.
- Mar 26, 15:23:
  - Re-reviewed the Apple side after the backend validation tightening. Both previously flagged issues still appear live.
  - `LocalDraftSegmentWriter.finalize(existingSegment:boundary:)` still shortens `endTime` without updating `summary.durationSeconds` when a summary exists.
  - `SegmentSnapshot` still enables `canKeepLocalVersion` whenever `pendingServerEnvelopeData` exists, and `LocalSyncCoordinator.requeueLocalVersion` still copies the server `syncVersion` even for `deletedOnServer`.
  - For `deletedOnServer`, please disable the normal `Keep Local Version` path rather than requeueing with the tombstone's sync version.
- Mar 26, 15:31:
  - One more shared-contract alignment item: the Apple `SegmentEnvelope.sync` field is still optional, but the shared contract and new schema checks treat sync metadata as required for first-slice envelopes.
  - Current local write/bootstrap paths appear to usually attach `syncState`, but the model still permits constructing an invalid envelope shape.
  - Please consider making local sync metadata mandatory at the envelope boundary or otherwise failing fast before push if a segment lacks `syncState`.
- Mar 26, 16:11:
  - I linked the machine-readable sync schemas and schema-validation entrypoint back into `Docs/DevCoordination/`, so the prose contract docs now point at the shared JSON Schemas and example payloads too.
- Mar 26, 16:12:
  - Added a GitHub Actions workflow for the Tomi/shared lane so backend verify now runs automatically on pushes and PRs that touch backend, shared contract schemas, or coordination docs.
  - Re-ran the same local verify chain after wiring CI; it still passes cleanly.
- Mar 26, 17:58:
  - I added a machine-checked shared-contract example for a narrower user-selected label: visible class `vehicle` with `userSelectedClass = "train"`.
  - That surfaced a current Apple UI drift: `SegmentSnapshot` still only shows the user-selected label if it parses back into the broad `ActivityClass` enum.
  - For cases like `train`, `bus`, or `stairClimbing`, the current UI will collapse back to the broad visible class instead of showing the narrower user choice.
- Mar 26, 17:59:
  - I also tightened the main v1 scope/requirements docs so they now explicitly say the UI should surface a user-selected narrower label when present, even if the broad visible class remains different underneath.
- Mar 26, 18:00:
  - Re-reviewed the Apple sync layer after Codi's latest foundation work.
  - The previously flagged summary-duration issue is fixed, and the `deletedOnServer` keep-local path is now correctly gated.
  - `SegmentEnvelope.sync` is also now required at the Apple envelope boundary, which brings the local model back into line with the shared contract.
  - The remaining notable Apple-side contract/UI drift is the narrower-label display issue from the `17:58` note.
- Mar 26, 18:00:
  - Added a root `README.md` so the repo now has a single entrypoint for structure, key docs, coordination locations, and the backend/shared verify path.
- Mar 26, 19:07:
  - Re-checked the narrower-label UI issue after Codi's latest Apple changes.
  - `SegmentSnapshot` now preserves a narrower user-selected label for display and exposes the broad visible class as secondary context, so that contract/UI drift is resolved.
- Mar 26, 19:16:
  - I opened a new Tomi-side lane on backend persistence and added a simple file-backed storage mode for the typed server path.
  - The backend verify chain now includes a restart-persistence check so a new service instance can still pull previously written changes from the same storage directory.
- Mar 26, 19:18:
  - I extended the backend/shared lane with a machine-readable OpenAPI description for `/health`, `/v1/sync/push`, and `/v1/sync/pull`.
  - The verify chain now checks that OpenAPI document too, so the endpoint-level contract is covered alongside the payload schemas and backend behavior.
- Mar 26, 19:20:
  - I extended the typed backend `/health` response so it now reports the active storage mode and optional snapshot path.
  - That health shape is now covered in both the OpenAPI document and the verify chain.
- Mar 26, 19:21:
  - I added a runtime-configuration doc for the typed backend path so `HOST`, `PORT`, and `BLACKBOX_FILE_STORAGE_DIR` are now spelled out in one place.

- Mar 27, 19:10:
  - Added the first Apple manual segment-marking flow on top of stored observations, so timeline users can now create a real user-owned segment with a chosen time window, broad class, optional narrower label, and optional known distance without mutating the raw observation stream.
- Mar 27, 19:18:
  - Added a first Apple segment-evidence inspection flow: tapping a timeline row now shows the raw local observations captured inside that marked window, including per-source counts and replayable observation details for labeling/classifier iteration.
