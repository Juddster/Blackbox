# Review Prompt

Use this prompt when asking another model to review the current Blackbox docs.

## Broad Review Prompt

```text
Review the docs in this repo as if you are a critical product/architecture reviewer.

Your job is not to rewrite them or expand them. Your job is to identify:
- contradictions between docs
- scope drift
- hidden assumptions
- overengineering
- missing decisions that will block implementation
- places where the docs are too vague to build from
- places where different docs imply different things
- risky architectural choices
- requirements that are not realistically supported by the platform assumptions

Focus especially on these files:
- docs/brainstorming/06-synthesis.md
- docs/07-architecture-overview.md
- docs/08-v1-scope-spec.md
- docs/09-v1-requirements-spec.md
- docs/10-domain-model-draft.md
- docs/11-apple-device-capabilities.md
- docs/12-implementation-phases.md
- docs/13-schema-draft.md
- docs/14-sync-storage-strategy.md
- docs/16-classification-pipeline.md
- docs/99-future-features.md

Review mode:
- Do not propose code.
- Do not rewrite the docs.
- Do not summarize the project unless needed for a finding.
- Findings first, ordered by severity.
- For each finding, cite the file(s) and explain the inconsistency, risk, or gap.
- After findings, give:
  - open questions
  - a short list of the top 3 docs that should be tightened before implementation

If you think a concern is only a mild suggestion rather than a real issue, separate it clearly under “Lower-priority observations”.
```

## Narrower Implementation-Readiness Review Prompt

```text
Review these docs specifically for implementation readiness:
- docs/08-v1-scope-spec.md
- docs/09-v1-requirements-spec.md
- docs/10-domain-model-draft.md
- docs/13-schema-draft.md
- docs/14-sync-storage-strategy.md
- docs/16-classification-pipeline.md

Look for:
- contradictions
- missing fields or concepts
- parts of the model that are overengineered for v1
- parts that are underdefined for implementation
- anything that will likely create confusion once coding starts

Findings first, ordered by severity, with file references.
```

## Suggested Use

- Start with the broad review prompt.
- If useful, follow with the narrower implementation-readiness review.
