# Shared Contract Schemas

These schema files are the machine-readable counterpart to the first-sync-slice coordination docs.

Current scope:
- `SegmentEnvelope`
- push request/response
- pull request/response

Source of truth alignment:
- `Docs/DevCoordination/api-shapes.md`
- `Docs/DevCoordination/sync-contract.md`
- `services/backend/contracts/http-examples.md`

Intent:
- give backend and future non-Apple clients a concrete payload target
- keep the first sync slice narrow
- avoid silently drifting from the shared contract prose
