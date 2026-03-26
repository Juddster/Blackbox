# Server Adapters

This folder holds runtime adapters around the framework-agnostic backend domain and route handlers.

Current scope:
- a Node HTTP adapter for local/demo use

It should remain thin:
- parse transport input
- call shared route/domain logic
- map the result back to HTTP
