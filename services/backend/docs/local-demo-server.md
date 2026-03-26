# Local Demo Server

This is a tiny no-dependency Node server for the first sync slice.

It exists to make the backend scaffold runnable before choosing:
- a real server framework
- a package manager strategy
- a TypeScript runtime/build path

## Start

```bash
node services/backend/demo-server.mjs
```

Default port:
- `8787`

Default host:
- `127.0.0.1`

Health check:

```bash
curl http://127.0.0.1:8787/health
```

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

- this server is for local smoke testing only
- it uses in-memory storage only
- it is intentionally not the long-term backend runtime
- the same logic is also available without opening a listener via:

```bash
node services/backend/demo-smoke.mjs
```
