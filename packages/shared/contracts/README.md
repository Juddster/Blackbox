# Shared Contract Schemas

These schema files are the machine-readable counterpart to the first-sync-slice coordination docs.

Current scope:
- `SegmentEnvelope`
- push request/response
- pull request/response
- canonical valid example payloads

Notable covered case:
- narrower user-selected labels that do not belong to the broad visible-class enum, such as `train` under visible class `vehicle`

Source of truth alignment:
- `Docs/DevCoordination/api-shapes.md`
- `Docs/DevCoordination/sync-contract.md`
- `services/backend/contracts/http-examples.md`

Intent:
- give backend and future non-Apple clients a concrete payload target
- keep the first sync slice narrow
- avoid silently drifting from the shared contract prose

Current executable check:
- `cd services/backend && npm run test:schemas`
