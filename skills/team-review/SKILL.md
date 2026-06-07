---
name: "plx::team-review"
description: "[SCAFFOLD] Team review (stage=review, tier=team). Read-only audit across Codex + Claude lanes per parallax.yaml, then synthesis. Not yet implemented as a distinct command."
argument-hint: "<what to review / audit>"
disable-model-invocation: true
user-invocable: true
---

# /plx:team-review — team review (SCAFFOLD)

**STATUS: scaffold — not yet implemented.**

Intended behavior: the review stage at the **team** tier — multiple read-only review lanes (debug + correctness across the engines configured for this command in `parallax.yaml`, e.g. Codex + Claude), then the orchestrator synthesizes findings. No edits unless the user asks for fixes.

Until implemented: use `/plx:review` (current review-only flow, which already runs Codex + Claude lanes by default).

Request:

$ARGUMENTS
