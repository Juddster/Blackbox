# Local Demo Server

This document covers two local server paths for the first sync slice.

They exist to make the backend scaffold runnable before choosing:
- a real server framework
- a package manager strategy
- a TypeScript runtime/build path

## Start

Legacy no-dependency demo server:

```bash
node services/backend/demo-server.mjs
```

Typed built server path:

```bash
cd services/backend
npm run build
npm run demo:server:built
```

Typed built server with file-backed persistence:

```bash
cd services/backend
npm run build
BLACKBOX_FILE_STORAGE_DIR=./tmp/dev-store npm run demo:server:built
```

Default port:
- `8787`

Default host:
- `127.0.0.1`

Health check:

```bash
curl http://127.0.0.1:8787/health
```

The typed server health response now includes:
- `ok`
- `storageMode`
- `snapshotPath` when file-backed storage is active

## Example Push

```bash
curl -X POST http://127.0.0.1:8787/v1/sync/push \
  -H 'content-type: application/json' \
  -d '{
    "deviceID": "iphone-1",
    "accountID": "account-123",
    "changes": [
      {
        "baseSyncVersion": 0,
        "segmentEnvelope": {
          "segment": {
            "id": "f6c0a0ee-1111-2222-3333-444444444444",
            "startTime": "2026-03-26T08:00:00Z",
            "endTime": "2026-03-26T08:45:00Z",
            "lifecycleState": "settled",
            "originType": "system",
            "primaryDeviceHint": "iPhone",
            "title": "Morning walk",
            "createdAt": "2026-03-26T08:46:00Z",
            "updatedAt": "2026-03-26T09:00:00Z"
          },
          "interpretation": {
            "id": "8ac1b7fd-1111-2222-3333-444444444444",
            "segmentID": "f6c0a0ee-1111-2222-3333-444444444444",
            "visibleClass": "walking",
            "userSelectedClass": null,
            "confidence": 0.82,
            "ambiguityState": "clear",
            "needsReview": false,
            "interpretationOrigin": "system",
            "updatedAt": "2026-03-26T09:00:00Z"
          },
          "summary": {
            "id": "9b7db3a0-1111-2222-3333-444444444444",
            "segmentID": "f6c0a0ee-1111-2222-3333-444444444444",
            "durationSeconds": 2700,
            "distanceMeters": 3200,
            "elevationGainMeters": 30,
            "averageSpeedMetersPerSecond": 1.18,
            "maxSpeedMetersPerSecond": 1.9,
            "pauseCount": 0,
            "updatedAt": "2026-03-26T09:00:00Z"
          },
          "sync": {
            "lastModifiedByDeviceID": "iphone-1",
            "lastModifiedAt": "2026-03-26T09:00:00Z",
            "syncVersion": 0,
            "isDeleted": false
          }
        }
      }
    ]
  }'
```

## Example Pull

```bash
curl -X POST http://127.0.0.1:8787/v1/sync/pull \
  -H 'content-type: application/json' \
  -d '{
    "deviceID": "iphone-1",
    "accountID": "account-123"
  }'
```

## Notes

- both server paths are for local smoke testing only
- the legacy `demo-server.mjs` path uses in-memory storage only
- neither is the long-term backend runtime
- the `demo-server.mjs` path is intentionally minimal and dependency-free
- the built TypeScript server path exercises the shared route handlers and sync service used by the main scaffold
- the built TypeScript server path can optionally use a simple file-backed store when `BLACKBOX_FILE_STORAGE_DIR` is set
- the same logic is also available without opening a listener via:

```bash
node services/backend/demo-smoke.mjs
```
