# Backend Skeleton

This folder is the starting point for the Blackbox backend.

Current intent:
- define the first sync-slice shape
- keep backend assumptions aligned with `Docs/DevCoordination/`
- avoid overcommitting to a server framework before the Apple sync payloads settle further

The current first sync slice is segment-envelope-centric.

Entry point:
- `services/backend/docs/README.md`

Current local scaffold:
- `package.json`
- `tsconfig.json`
- framework-agnostic TypeScript source under `src/`
- a no-dependency local demo server at `demo-server.mjs`
- a typed Node HTTP adapter under `src/server/`
- a file-backed storage mode for the typed server path
- a machine-readable OpenAPI description for the first sync slice

Verification:
- `npm run verify`

Health endpoint:
- the typed server path reports `ok`, `storageMode`, and optional `snapshotPath`

CI:
- `.github/workflows/backend-verify.yml`
