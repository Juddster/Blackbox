# Source Layout

This source layout is intentionally framework-agnostic for now.

Folders:
- `routes/`: request/response entry points
- `domain/`: sync-envelope and domain-level service logic
- `storage/`: persistence abstractions
- `conflicts/`: conflict resolution helpers

Current concrete scaffold:
- `domain/types.ts`
- `domain/validation.ts`
- `domain/sync-service.ts`
- `storage/interfaces.ts`
- `storage/memory.ts`
- `routes/http-types.ts`
- `routes/request-validation.ts`
- `routes/sync-handlers.ts`
- `demo/smoke-example.ts`
- `index.ts`
