# Blackbox

Blackbox is a local-first personal movement and activity journal.

The current repository state is early but structured:
- Apple client work lives under `apps/apple/`
- shared product and architecture docs live under `docs/`
- backend and sync work lives under `services/backend/`
- machine-readable shared sync contracts live under `packages/shared/contracts/`

## Current Focus

The project currently has:
- v1 product/scope/requirements docs
- Apple client foundation work in progress
- a first backend sync-slice scaffold
- shared sync contract schemas and examples

The current first sync slice is intentionally narrow:
- `SegmentEnvelope`
- push
- pull
- tombstones
- conflict handling

Deferred for later:
- collections as first-class sync units
- exports as first-class sync units
- dense raw observation upload
- live sharing

## Important Locations

- `docs/07-architecture-overview.md`
- `docs/08-v1-scope-spec.md`
- `docs/09-v1-requirements-spec.md`
- `docs/13-schema-draft.md`
- `docs/14-sync-storage-strategy.md`
- `docs/16-classification-pipeline.md`
- `docs/DevCoordination/`
- `apps/apple/Docs/TomiCodi.md`
- `services/backend/`
- `packages/shared/contracts/`

## Backend / Shared Verification

From `services/backend/`:

```bash
npm install
npm run verify
```

That verification path currently covers:
- TypeScript typecheck
- backend build output
- in-memory sync smoke checks
- built-output smoke checks
- HTTP handler checks
- shared schema/example validation

## Apple Work

Apple client implementation is in progress under `apps/apple/`.

Important coordination rules:
- cross-boundary contract/source-of-truth docs live under `docs/DevCoordination/`
- Tomi/Codi coordination happens in `apps/apple/Docs/TomiCodi.md`

## Notes

- This repo uses GitHub Actions for the backend/shared verification lane.
- The Apple client and Xcode workspace are actively evolving.
- Some repo areas are intentionally reserved for later platforms (`apps/android`, `apps/web`, `packages/swift`, `services/`).
