# HTTP Status And Error Rules

This document defines the expected HTTP-level behavior for the first backend sync slice.

It complements:
- [push-pull-semantics.md](/Users/judd/DevProjects/Blackbox/services/backend/docs/push-pull-semantics.md)
- [validation-rules.md](/Users/judd/DevProjects/Blackbox/services/backend/docs/validation-rules.md)
- [conflict-response-examples.md](/Users/judd/DevProjects/Blackbox/services/backend/docs/conflict-response-examples.md)

## Goal

Make the first sync slice predictable at the transport level so:
- Apple client code knows what to treat as transport failure vs semantic failure
- backend implementation does not improvise status codes per route

## Route Scope

These rules apply to:
- `POST /v1/sync/push`
- `POST /v1/sync/pull`

## Success Responses

### Push Success

Use `200 OK` when the request was parsed and processed, even if some individual changes conflicted.

Why:
- per-change conflicts are part of normal sync semantics
- they are represented inside the response body, not as transport failure

### Pull Success

Use `200 OK` when the request was parsed and changes were returned successfully, including:
- zero changes
- only tombstones
- paginated partial change sets

## Client Payload Errors

Use `400 Bad Request` when:
- request JSON is malformed
- required top-level request fields are missing
- the overall request shape is invalid before per-envelope processing can begin

Use `422 Unprocessable Entity` when:
- the request parsed correctly
- but one or more envelopes fail semantic validation

Examples:
- `interpretation.segmentID` does not match `segment.id`
- `segment.endTime < segment.startTime`
- enum values are invalid

If the backend chooses to keep all client payload failures under `400`, that is acceptable for v1 as long as it stays consistent.  
The important rule is consistency and a clear distinction from sync conflicts.

## Authentication / Authorization

Use:
- `401 Unauthorized` when authentication is missing or invalid
- `403 Forbidden` when the caller is authenticated but not allowed to act on the specified account

## Conflict Semantics

Do not use `409 Conflict` for ordinary per-change sync conflicts inside a valid push batch.

Instead:
- return `200 OK`
- include conflicts inside the push response body

Why:
- batch requests may include a mix of accepted and conflicted changes
- the client needs per-change handling, not request-level failure semantics

## Server Failures

Use `500 Internal Server Error` when:
- an unexpected backend failure prevents processing

Use `503 Service Unavailable` when:
- the backend is temporarily unable to serve sync reliably

The client should treat both as retryable transport/service failures, not as semantic sync outcomes.

## Response Body Rules

### Validation Errors

Use the shared validation error shape:

```json
{
  "code": "invalidPayload",
  "message": "interpretation.segmentID must match segment.id",
  "field": "interpretation.segmentID"
}
```

### Push Success With Mixed Outcomes

Use the push response body even when some changes conflicted:

```json
{
  "accepted": [],
  "conflicts": []
}
```

### Pull Success

Use the pull response body:

```json
{
  "changes": [],
  "nextCursor": "opaque-string",
  "hasMore": false
}
```

## Apple Client Implications

The Apple client should treat:
- `200 OK` push responses with populated `conflicts` as normal sync outcomes
- `4xx` request/validation failures as client-side problems to surface or log
- `5xx` and transport failures as retryable network/service issues

## Non-Goals

This document does not define:
- rate limiting behavior
- live-share streaming transport rules
- web-facing public API conventions
