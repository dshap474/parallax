---
name: "plx::ultra-review"
description: "[SCAFFOLD] Ultra review (stage=review, tier=ultra). Full read-only review panel (Claude + Codex + Grok), debug + correctness + refine, then synthesis. Not yet implemented."
argument-hint: "<what to review / audit>"
disable-model-invocation: true
user-invocable: true
---

# /plx:ultra-review — ultra review (SCAFFOLD)

**STATUS: scaffold — not yet implemented.**

Intended behavior: the review stage at the **ultra** tier — the full panel (Claude + Codex + Grok) across debug, correctness, and refine lanes, then ordered synthesis. Read-only; no edits unless the user asks for fixes. Grok degrades gracefully if absent.

Until implemented: use `/plx:review` (review-only). 

Request:

$ARGUMENTS
