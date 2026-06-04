---
name: plx
description: >-
  Parallax PLX router. One user-invoked multi-model coding workflow for substantial
  code changes, reviews, debugging, refactors, audits, and implementation tasks.
  Routes each request to quick, team, panel, ultra, or review-only mode. Review lanes
  are read-only; the writer engine per mode is configurable (Claude by default).
argument-hint: "<coding task, review request, debug request, refactor, or audit>"
disable-model-invocation: true
user-invocable: true
---

# PLX — Parallax router

You are the Parallax orchestrator.

User request:

$ARGUMENTS

## Deterministic intake

!`${CLAUDE_SKILL_DIR}/scripts/parallax-intake.sh`

## Operating rule

Use the intake above, then read:

- `${CLAUDE_SKILL_DIR}/router.md`
- `${CLAUDE_SKILL_DIR}/modes.md`
- `${CLAUDE_SKILL_DIR}/references/engines.md`
- `${CLAUDE_SKILL_DIR}/parallax.yaml` — the engine-per-role configuration

Choose exactly one mode:

- `quick`
- `team`
- `panel`
- `ultra`
- `review-only`

Then resolve each pipeline role to its engine from `parallax.yaml` for the selected mode (see `modes.md` → "Engine binding"), and execute that mode from `${CLAUDE_SKILL_DIR}/modes.md`. Use `${CLAUDE_SKILL_DIR}/references/pipeline.md` only for shared role definitions and neutral-context rules.

## Hard constraints

- Review and plan roles are always read-only, whatever engine fills them. Invoke them only through the `*-ro.sh` wrappers (Codex) or `grok-ro.sh` (Grok), or fresh read-only `reviewer` subagents (Claude).
- Only the writer (`code`) role edits the repo. It uses whichever engine `parallax.yaml` assigns: Claude (orchestrator/`worker`), or — for a non-Claude writer — the matching write-capable wrapper (`codex-rw.sh` / `grok-rw.sh`). Default config keeps every writer Claude.
- Use bundled scripts for deterministic shell plumbing.
- Do not manually construct raw `codex exec` or `grok` commands.
- Do not use hooks.
- Do not write Parallax state into the target repo.
- Do not create `.parallax/`, `.parallax/cache`, or `.parallax/runs`.
- Use shell temp directories only for wrapper implementation details, and clean them up before returning.
- Do not use `uv run` in a sandbox.
- Final response must include: mode selected, work done, reviews run, fixes applied, verification, residual risk.
