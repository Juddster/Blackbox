# Backend Docs Index

These docs define the minimal backend direction for Blackbox before real server implementation begins.

Read them in this order:

1. [overview.md](/Users/judd/DevProjects/Blackbox/services/backend/docs/overview.md)
2. [first-sync-slice.md](/Users/judd/DevProjects/Blackbox/services/backend/docs/first-sync-slice.md)
3. [push-pull-semantics.md](/Users/judd/DevProjects/Blackbox/services/backend/docs/push-pull-semantics.md)
4. [validation-rules.md](/Users/judd/DevProjects/Blackbox/services/backend/docs/validation-rules.md)
5. [conflict-response-examples.md](/Users/judd/DevProjects/Blackbox/services/backend/docs/conflict-response-examples.md)
6. [storage-shape.md](/Users/judd/DevProjects/Blackbox/services/backend/docs/storage-shape.md)
7. [implementation-checklist.md](/Users/judd/DevProjects/Blackbox/services/backend/docs/implementation-checklist.md)
8. [http-status-and-errors.md](/Users/judd/DevProjects/Blackbox/services/backend/docs/http-status-and-errors.md)
9. [../contracts/http-examples.md](/Users/judd/DevProjects/Blackbox/services/backend/contracts/http-examples.md)
10. [local-demo-server.md](/Users/judd/DevProjects/Blackbox/services/backend/docs/local-demo-server.md)

Supporting contract source of truth:
- [sync-contract.md](/Users/judd/DevProjects/Blackbox/Docs/DevCoordination/sync-contract.md)
- [api-shapes.md](/Users/judd/DevProjects/Blackbox/Docs/DevCoordination/api-shapes.md)
- [conflict-resolution.md](/Users/judd/DevProjects/Blackbox/Docs/DevCoordination/conflict-resolution.md)

## Intent

The current backend direction is intentionally narrow:
- first sync slice is `SegmentEnvelope` only
- backend stays current-state oriented
- collections, exports, and first-class review sync are deferred
- storage and conflict behavior are defined only enough to support Apple offline durability and catch-up

Verification entrypoint:
- `npm run verify`

Automation:
- `.github/workflows/backend-verify.yml`

Runtime entrypoints:
- `node services/backend/demo-server.mjs`
- `cd services/backend && npm run build && npm run demo:server:built`
