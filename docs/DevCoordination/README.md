# Dev Coordination

This folder is the shared source of truth for cross-boundary coordination between:
- Apple client work
- backend/shared contract work
- Tomi/Codi alignment when a decision affects more than the Apple workspace

## Ownership

- Tomi owns writes and structural changes in this folder.
- Codi reads from this folder and can request changes through the coordination process.

## Purpose

These docs should stay:
- implementation-aware
- contract-focused
- narrower than the broad product/design docs under `docs/`

They should not:
- mirror Apple implementation details unnecessarily
- become a second full architecture set
- drift away from the repo-wide docs without an explicit decision

## Current Files

- `api-shapes.md`
- `client-sync-state.md`
- `conflict-resolution.md`
- `sync-contract.md`
