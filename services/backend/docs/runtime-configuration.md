# Runtime Configuration

This document describes the current runtime knobs for the typed backend server path.

It applies to:
- `cd services/backend && npm run build && npm run demo:server:built`

It does not apply to:
- `demo-server.mjs`, which remains the minimal dependency-free path

## Environment Variables

### `HOST`

Default:
- `127.0.0.1`

Purpose:
- controls which interface the typed backend server listens on

### `PORT`

Default:
- `8787`

Purpose:
- controls which port the typed backend server listens on

### `BLACKBOX_FILE_STORAGE_DIR`

Default:
- unset

Behavior:
- when unset, the typed backend server uses in-memory storage
- when set, the typed backend server uses the simple file-backed storage mode

Current effect:
- persisted sync state is stored in `sync-state.json` under the configured directory
- `/health` reports both `storageMode` and the active `snapshotPath` when file-backed mode is enabled

## Current Recommendation

For quick local smoke testing:

```bash
cd services/backend
npm run build
npm run demo:server:built
```

For local restart persistence:

```bash
cd services/backend
npm run build
BLACKBOX_FILE_STORAGE_DIR=./tmp/dev-store npm run demo:server:built
```

## Non-Goals

This does not yet define:
- production secret management
- auth configuration
- database configuration
- cloud deployment settings
