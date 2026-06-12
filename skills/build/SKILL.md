---
name: "plx::build"
description: Build from a plan, standalone (dev steps 4–5). One worker implements the spec, spawns the read-only review lanes inside its own context, fixes or rebuts every finding, and returns a Buildout report. The orchestrator supplies the spec — already in hand, or written from the request — and relays the report.
argument-hint: "<coding task, or a plan to build>"
disable-model-invocation: true
user-invocable: true
---

# /plx:build — build from a plan

You are the Parallax orchestrator (Fable). This skill is the build stage of the dev
pipeline, run standalone. One worker does the heavy lifting: it implements the spec,
runs the review round inside its own context, fixes or rebuts every finding, and hands
you one Buildout report. Your job is small — supply the spec, dispatch the worker, relay
the report. Do not study the codebase or read the diff yourself; the worker and its
review lanes own that.

## Bootstrap

Establish ground truth with your own tools — nothing is injected for you:

- Resolve the absolute repo root (`git rev-parse --show-toplevel`); call it `<repo>`.
- If the worktree is dirty, note `git status --short` — so pre-existing edits aren't
  mistaken for the build's.

## Engines & preflight

Read the engine config (run `plx-config`) → key `build`. Shipped defaults:
`code: claude` · each review dimension `[codex]`. Run
`plx-preflight --repo <repo> --require-codex`. If Codex is unavailable, stop and say
so — the worker's review round needs it.

## Pipeline (run in order)

1. **Get the spec.** If you already have a plan — authored earlier in this conversation,
   or a file the user points at — use it as-is. Otherwise write one yourself from the
   user's request: outcome-first, for a high-effort autonomous worker with no prior
   context. Pin intent, success criteria, and invariants hard; leave the *how* to the
   worker. Use this shape:

   ```
   # Plan: <title>

   ## Worker Instruction
   <implement the task below; simplest change satisfying the success criteria; prefer existing project patterns; validate at boundaries; don't expand scope>

   ## Intent
   <why this change matters and what it enables — 2–5 sentences>

   ## Success Criteria
   <binary checks defining done, including edge cases and regressions that must hold>

   ## Context
   <relevant files + why; current vs. desired behavior; existing patterns to reuse>

   ## Invariants
   <the only hard rules — do-not-touch files/areas, contracts that must hold>

   ## Suggested Path
   <non-binding: likely files, likely implementation shape — the worker may choose a better path>

   ## Validation
   <smallest set of repo commands that meaningfully proves the task, and what passing looks like>
   ```

2. **Dispatch the worker.** Write the spec to a file in a `mktemp -d` dir. Resolve the
   review lanes from the config (`review-correctness` and `review-refine` keys →
   personas, e.g. `[codex]` → `plx:codex-reviewer-correctness` +
   `plx:codex-reviewer-refine`). Spawn the `code` engine's worker (default
   `plx:claude-worker`) with `<repo>` + the spec file path + the reviewer persona
   names — nothing else. One writer, always.

   The worker does the rest itself: implements the spec, self-verifies with the repo's
   own checks, spawns the named review lanes in parallel inside its own context, fixes
   or rebuts every finding (one round, hard cap), re-verifies, and reports.

3. **Receive the Buildout report**: every file touched with per-file summaries, coding
   decisions, verification runs, and the review disposition — per finding: fixed,
   rebutted (with evidence), or residual. Summaries only — if the report contains code
   bodies, that's a worker error; do not read them.

4. **Deliver and stop.** Relay the report compactly, then stop — no final gate, no
   commit, no docs pass here; that full loop is `/plx:dev`. Clean up the temp dir.
   End with:

   ```text
   Built: <what shipped>
   Spec: <used as given | written from the request — one line on the approach>
   Review: <lanes the worker spawned; findings — fixed / rebutted / residual>
   Verification: <commands + results, from the report>
   Residual risk: <what to watch>
   ```

## Hard constraints

- The worker is the only writer. It spawns only the reviewer personas you name in its
  dispatch — never planners, other workers, or docs agents.
- Review lanes are read-only, whatever engine fills them.
- Hand the worker the work, not the command — repo path + spec path + lane names. The
  personas own their rubrics and their `plx-*` tool invocations.
- Never hand-construct raw `codex exec` or `grok` commands.
- Do not write Parallax state into the target repo — no `.parallax/` dirs. Temp files
  live in `mktemp -d` dirs, cleaned up before returning.
- Never `uv run` inside a sandbox.

Task:

$ARGUMENTS
