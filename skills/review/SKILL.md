---
name: "plx::review"
description: Force Parallax review (stage=review, no edits). Read-only audit/debug/correctness lanes per config/parallax.yaml; synthesizes findings. Does not modify files unless you explicitly ask for fixes.
argument-hint: "<what to review / debug / audit>"
disable-model-invocation: true
user-invocable: true
---

# /plx:review — review (review stage · no edits)

You are the Parallax orchestrator. This skill **is** the read-only review pipeline. Do **not** run the router's mode-selection. **Do not edit files** unless the user explicitly asked for fixes.

## Deterministic intake

!`${CLAUDE_PLUGIN_ROOT}/scripts/parallax-intake.sh`

## Setup (read once)

- `${CLAUDE_PLUGIN_ROOT}/lib/pipeline.md` — grammar: subagent injection, neutral-context rule, shared rules.
- `${CLAUDE_PLUGIN_ROOT}/lib/engines.md` — how to invoke each engine.
- `${CLAUDE_PLUGIN_ROOT}/config/parallax.yaml` → key `review-only` — resolve review-lane engines. Defaults:
  - `review-debug: [codex, claude]` · `review-correctness: [codex, claude]` · `review-refine: [codex, claude]`

Run `${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh --repo <repo> --require-codex` if any selected lane uses Codex (the default). If you select only Claude lanes, no external preflight is needed.

## Pipeline (run in order)

1. **Scope** — identify what to review; build the review pack (files / diff / target).
2. **Choose lanes** from the user's intent (one or more):
   - correctness — block `${CLAUDE_PLUGIN_ROOT}/prompts/correctness.md` — "does this satisfy X?"
   - debug — block `${CLAUDE_PLUGIN_ROOT}/prompts/debug.md` — bugs / failures
   - refine — block `${CLAUDE_PLUGIN_ROOT}/prompts/refine.md` — cleanup / simplification
   - security — surface only if obvious and recommend a dedicated pass; this is **not** a security audit.
3. **Run lanes** — one read-only `plx:<engine>-reviewer` per engine in the matching `review-*` list, neutral context. Build prompts with `scripts/make-review-prompt.sh`.
4. **Synthesize** — block `${CLAUDE_PLUGIN_ROOT}/prompts/synthesis.md` (Ordered Synthesis). Report findings accepted/rejected, severity-ranked.
5. **Report** — findings only. **Do not edit** unless the user explicitly asked for fixes.

> Tiering note: `/plx:team-review` and `/plx:ultra-review` (scaffold) will run this pipeline at wider lane sets. For now this command uses the `review-only` defaults in `config/parallax.yaml`.

Request:

$ARGUMENTS
