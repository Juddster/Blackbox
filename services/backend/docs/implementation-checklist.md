# First-Slice Backend Implementation Checklist

This checklist turns the current backend docs into a practical implementation order.

It is intentionally limited to the first sync slice.

## 1. Contract Lock

- Treat [sync-contract.md](/Users/judd/DevProjects/Blackbox/Docs/DevCoordination/sync-contract.md) as the source of truth.
- Treat [api-shapes.md](/Users/judd/DevProjects/Blackbox/Docs/DevCoordination/api-shapes.md) as the shared payload vocabulary.
- Confirm first slice remains `SegmentEnvelope` only.

## 2. Storage Foundation

- Create account-scoped current envelope storage.
- Create monotonic per-segment `syncVersion` handling.
- Create account-scoped sync feed ordering.
- Decide tombstone retention mechanics.

## 3. Push Path

- Implement `POST /v1/sync/push`.
- Validate incoming payloads.
- Distinguish validation failures from version conflicts.
- Accept new records and matching-version updates.
- Return per-change acceptance results.
- Return server-envelope conflicts for mismatches and deleted-on-server cases.

## 4. Pull Path

- Implement `POST /v1/sync/pull`.
- Accept optional opaque cursor.
- Return stable ordered segment-envelope changes.
- Include tombstones in ordinary change flow.
- Return `nextCursor` and `hasMore`.

## 5. Conflict Behavior

- Use envelope-level conflict handling.
- Preserve user-authored interpretation over weaker system-authored state.
- Avoid surprising silent server-side merges.
- Use [conflict-response-examples.md](/Users/judd/DevProjects/Blackbox/services/backend/docs/conflict-response-examples.md) as the expected behavior guide.

## 6. Retry / Idempotency Safety

- Ensure retries do not duplicate durable segment rows.
- Ensure ambiguous retry sequences converge to one current server envelope.
- Keep idempotency mechanics implementation-specific if needed, but make observable behavior stable.

## 7. Basic Verification

- Verify new segment push and pull round trip.
- Verify ordinary update with matching `baseSyncVersion`.
- Verify version-mismatch conflict response.
- Verify tombstone push then pull visibility.
- Verify malformed payload rejection.

## Explicitly Deferred

- collection sync
- export sync
- first-class review sync
- dense observation upload
- live sharing
