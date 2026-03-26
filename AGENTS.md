# Project Instructions


## Repo Roles

This repo currently has two coordinated Codex agents:

- `Tomi`: lead developer, repo-wide driver
- `Codi`: Apple client owner working from Xcode

## Responsibility Split

### Tomi Owns

- repo-wide product direction
- architecture and design docs under `docs/`
- sync/storage strategy
- schema and domain-model direction
- backend/shared contract direction
- cross-boundary coordination docs
- deciding when implementation is drifting from agreed design

### Codi Owns

- Apple client implementation
- Xcode workspace/project upkeep
- iPhone app code
- future watchOS client code
- Apple-specific implementation decisions within agreed repo-wide constraints

## Coordination Workflow

The shared coordination file between Tomi and Codi is:

- `apps/apple/Docs/TomiCodi.md`

The shared contract docs for Apple/backend/shared coordination live under:

- `Docs/DevCoordination/`

### Standing Rule For Tomi

Before starting any substantive task, Tomi should:
- read `apps/apple/Docs/TomiCodi.md`

After finishing any substantive task, Tomi should:
- read `apps/apple/Docs/TomiCodi.md` again
- update `Tomi Progress Notes` and/or `Tomi Instructions To Codi` if needed

### Standing Rule For Codi

Codi should use `apps/apple/Docs/TomiCodi.md` for:
- progress notes
- reading Tomi instructions
- identifying cross-boundary decisions that require repo-wide doc updates

Before starting any substantive task, Codi should:
- read `apps/apple/Docs/TomiCodi.md`

After finishing any substantive task, Codi should:
- read `apps/apple/Docs/TomiCodi.md` again
- update his progress notes as needed

## Coordination Note Format

In `apps/apple/Docs/TomiCodi.md`:

- `Codi Progress Notes` are for Apple implementation progress
- `Tomi Progress Notes` are for Tomi’s coordination/design progress
- `Tomi Instructions To Codi` are for actionable instructions to the Apple client owner

Timestamp format for new notes:

- `Mar 26, 14:55:`

If several bullets belong to the same timestamp, indent them under that timestamp.

## Contract Source Of Truth

Cross-boundary sync/API/conflict docs should use:

- `Docs/DevCoordination/`

as the source of truth, rather than Apple implementation details.

## General Working Style

- Keep local-first behavior central.
- Do not let Apple persistence details become the canonical cross-platform model.
- Keep v1 implementation practical and avoid premature overengineering.

## Work autonomously
Work autonomously until the task is fully complete.

Do not stop after the first trivial change.
Keep searching, editing, building, testing, and fixing follow-on issues until all of these are true:
1. the requested behavior is implemented,
2. the relevant tests pass, or you add and run them if missing,
3. the code builds cleanly,
4. obvious adjacent breakages are checked,
5. you are genuinely blocked by missing information, credentials, or a consequential product decision.

Do not ask me for confirmation on routine implementation choices.
Make reasonable assumptions, proceed, and report them at the end.
Only return when you are actually blocked or the work is complete.

## Commit And Push Policy

When work reaches a stable condition:
- code builds with no issues
- relevant tests pass, if a test target exists
- no obvious adjacent breakages remain

then commit and push after each substantive step.

Do not commit or push unstable or knowingly broken code.

Commit messages must use this format:
- first line: a concise one-line summary
- then a blank line
- then flat bullet points listing the changes included in that step

The bullet points should be detailed enough to explain what changed without opening the diff.
