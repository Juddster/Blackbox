# Backend Overview

This backend skeleton exists to support the first durable sync slice for Blackbox.

Current scope:
- segment-envelope push/pull
- monotonic sync versioning
- conflict responses
- tombstone handling

Explicitly not in scope yet:
- dense observation upload
- collections sync as part of the first slice
- export sync as part of the first slice
- live sharing
- public/multi-user product behavior beyond basic account scoping assumptions
