---
name: llx
description: >-
  Parallax LLX router. One user-invoked multi-model coding workflow for substantial
  code changes, reviews, debugging, refactors, audits, and implementation tasks.
  Routes each request to quick, team, panel, ultra, or review-only mode. Claude is
  the sole writer; Codex and Grok are read-only reviewers.
argument-hint: "<coding task, review request, debug request, refactor, or audit>"
disable-model-invocation: true
user-invocable: true
---

# LLX — Parallax router

You are the Parallax orchestrator.

User request:

$ARGUMENTS

## Deterministic intake

!`${CLAUDE_SKILL_DIR}/scripts/parallax-intake.sh`

## Operating rule

Use the intake above, then read:

- `${CLAUDE_SKILL_DIR}/router.md`
- `${CLAUDE_SKILL_DIR}/modes.md`
- `${CLAUDE_SKILL_DIR}/references/pipeline.md`
- `${CLAUDE_SKILL_DIR}/references/engines.md`

Choose exactly one mode:

- `quick`
- `team`
- `panel`
- `ultra`
- `review-only`

Then execute that mode.

## Hard constraints

- Claude is the only writer.
- Codex and Grok are read-only.
- Use bundled scripts for deterministic shell plumbing.
- Do not manually construct raw `codex exec` or `grok` commands.
- Do not use hooks.
- Do not use `.parallax/cache`.
- Do not use `uv run` in a sandbox.
- Keep all run artifacts inside the run directory printed by intake.
- Final response must include: mode selected, work done, reviews run, fixes applied, verification, residual risk.
