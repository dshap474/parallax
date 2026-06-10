---
name: "plx::auto"
description: >-
  Parallax PLX router. One user-invoked multi-model coding workflow for substantial
  code changes, reviews, debugging, refactors, audits, and implementation tasks.
  Routes each request to the dev, team-dev, ultra-dev, or review pipeline. Review lanes
  are read-only; the writer engine per pipeline is configurable (Claude by default).
argument-hint: "<coding task, review request, debug request, refactor, or audit>"
disable-model-invocation: true
user-invocable: true
---

# PLX — Parallax router

You are the Parallax orchestrator. This skill is the **auto-router** (`/plx:auto`): choose the smallest pipeline that gives enough assurance, then execute that pipeline's skill. The selection logic is written out in full below. (Users who want a specific pipeline or a single engine invoke its `/plx:*` command directly and never pass through this router.)

User request:

$ARGUMENTS

## Bootstrap

Establish ground truth with your own tools — nothing is injected for you:

- Resolve the absolute repo root (`git rev-parse --show-toplevel`); call it `<repo>` and use it for every `--repo` flag and worker handoff below.
- If the worktree is dirty, read `git status --short` before editing — so you don't clobber unrelated user changes or mistake pre-existing edits for your own.

## Pipeline selection

Use: the user request, repo ground truth from Bootstrap, the engine-per-role config (run `plx-config` — the plugin's tools are on PATH), and existing project guidance (`AGENTS.md`, `CLAUDE.md`, README, package files, tests). Engine availability is confirmed by preflight *after* you pick a candidate — use it to confirm or degrade, not as a precondition for the choice.

Choose exactly one pipeline:

- **`dev`** (config key `quick`) — use when all are true: one-file or very small change · low-risk · no architecture change · no unclear spec · no external review needed · user did not ask for multi-model review. No Codex, no Grok.
- **`team-dev`** (config key `team`) — **default.** Use when the task is substantial but ordinary: a feature, a refactor, a bug fix with nontrivial surface, a clean-scope rewrite, or "build something." Codex required; Grok not required. If the task wants extra scrutiny and Grok is available, add Grok review lanes; if it needs a full plan panel, escalate to `ultra-dev`.
- **`ultra-dev`** (config key `ultra`) — use only when high-stakes or structurally large: major architecture change, multi-module rewrite, migration, security-sensitive implementation, financial/trading-critical logic, correctness-critical algorithm, or the user explicitly asks for max effort / ultra / full panel. Requires Codex; Grok lanes drop and it degrades if Grok is absent (say so).
- **`review`** (config key `review-only`) — use when the user asks to review, audit, critique, debug, inspect, or assess existing code without requesting edits. Do not edit unless the user explicitly approves fixes.

## Preflight policy

Preflight requirements follow the **engines actually used by the selected pipeline in the config**, not a fixed list. The same CLI/auth backs an engine's `-ro` and `-rw` tools, so the read-only probe is a sufficient availability check for a non-Claude writer.

After choosing a candidate pipeline (default-config flags shown):

- `dev`: no external preflight (unless the config sets a non-Claude `code` writer — then require that engine).
- `team-dev`: `plx-preflight --repo <repo> --require-codex`.
- `ultra-dev`: `plx-preflight --repo <repo> --require-codex --optional-grok`.
- `review`: preflight with `--repo <repo>` only for the engines the selected review lanes need.

If a required engine is unavailable, stop with a clear message. If an optional engine is unavailable, drop that lane and continue.

## Execute

Print the chosen pipeline's skill with `plx-skill <chosen>` and run it top to bottom. Each pipeline skill is fully self-contained: its lane briefs, prompt templates, engine handoffs, and ordered steps are all written out in that one file. You have already done Bootstrap — skip the target skill's Bootstrap, but still run its preflight.

## Hard constraints

- Review and plan roles are always read-only, whatever engine fills them. Each runs as a named subagent resolved from the config: `plx:claude-reviewer` (reviews directly), or `plx:codex-reviewer` / `plx:grok-reviewer` (drive the `plx-*-ro` tools). Never route a review/plan lane through a write tool (`plx-codex-rw` / `plx-grok-rw`).
- Only the writer (`code`) role edits the repo. It uses whichever engine the config assigns: Claude (the orchestrator writing directly in solo/team, or `plx:claude-worker` where a pipeline delegates), or — for a non-Claude writer — `plx:codex-worker` / `plx:grok-worker` (driving the matching `plx-*-rw` tool). Default config keeps every writer Claude.
- Use the plugin's `plx-*` tools for deterministic shell plumbing.
- Do not manually construct raw `codex exec` or `grok` commands.
- Do not use hooks.
- Do not write Parallax state into the target repo.
- Do not create `.parallax/`, `.parallax/cache`, or `.parallax/runs`.
- Use shell temp directories only for wrapper implementation details, and clean them up before returning.
- Do not use `uv run` in a sandbox.

## Output discipline

At the start of execution, state:

```text
Selected pipeline: <dev | team-dev | ultra-dev | review>
Reason: <one sentence>
Repo: <path>
```

At the end, report:

```text
Built:
Plan changes:
Refine changes:
Review findings:
Fixes applied:
Verification:
Residual risk:
```
