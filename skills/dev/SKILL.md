---
name: "plx::dev"
description: Solo build (stage=dev, tier=solo). Claude plans, edits directly, and verifies — no plan-review, no review lanes. The lightest build pipeline; the former 'quick' flow.
argument-hint: "<small / contained coding task>"
disable-model-invocation: true
user-invocable: true
---

# /plx:dev — solo build (dev · solo tier)

You are the Parallax orchestrator. This skill **is** the solo build pipeline, written out in full — the lightest one: plan, write, verify, with **no plan-review and no review lanes**. Do **not** run the router's mode-selection.

## Bootstrap

Establish ground truth with your own tools — nothing is injected for you:

- Resolve the absolute repo root (`git rev-parse --show-toplevel`); call it `<repo>`.
- If the worktree is dirty, read `git status --short` before editing — so you don't clobber unrelated user changes or mistake pre-existing edits for your own.

## Engines & preflight

Read the engine config (run `plx-config`) → key `quick`. Shipped default: `code: claude` — you write directly; no external engines, no preflight. Only if the config sets a non-Claude `code` writer: run `plx-preflight --repo <repo> --require-<engine>` first, then spawn `plx:codex-worker` or `plx:grok-worker` with the repo path and the spec file (each drives its `plx-*-rw` tool inside a repo-scoped sandbox) and review the returned diff.

## Shared rules

- Do not write Parallax state into the target repo — no `.parallax/` dirs. Keep working notes in chat or `mktemp -d` temp dirs, cleaned up before returning.
- Verify with the repo's own toolchain binaries (`.venv/bin/ruff`, `.venv/bin/pytest`, npm/cargo/go…). Never `uv run` inside a sandbox — Homebrew `uv` panics there.

## Pipeline (run in order)

1. **Plan** (kept minimal) — inspect the target files, their immediate callers/callees, and project guidance (`AGENTS.md`, `CLAUDE.md`, sibling files to mirror). Write a short plan: what changes, in which files, what you will *not* touch, and how you'll verify. No plan-review lane.
2. **Code** — edit directly with Edit/Write. Build exactly what the plan says: pin interfaces and names before typing, touch only the planned files, reuse existing helpers instead of writing new ones, no speculative abstraction, no options nothing calls. Match the surrounding file's conventions — naming, error handling, import style. Before finishing, sweep your own slop: dead branches, leftover debug statements, unused imports, comments that restate the code, single-call wrappers.
3. **Verify** — run the repo's narrowest relevant checks (the tests/typecheck/lint nearest the change). Do not invent new harnesses; never `uv run` in a sandbox. Report what you ran and the result.
4. **Report** — Built · Verification · Residual risk.

If the change turns out to be substantial or risky — architecture change, multi-module surface, unclear spec — stop and recommend `/plx:team-dev` (build with multi-model review).

Task:

$ARGUMENTS
