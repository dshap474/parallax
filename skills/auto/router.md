# Parallax PLX Router

The user invoked `/plx:auto`.

Your job is to choose the smallest pipeline that gives enough assurance. This file owns **pipeline selection and preflight policy only**; each skill owns its pipeline steps (`skills/<name>/SKILL.md` → "## Pipeline"), and `lib/pipeline.md` owns the shared grammar.

## Inputs

Use:

1. User request from `SKILL.md`.
2. Deterministic intake output.
3. Current repo state.
4. Available engines (resolved by preflight, which runs *after* you pick a candidate pipeline — see Preflight policy; use it to confirm or degrade, not as a precondition for the choice).
5. Engine-per-role config in `${CLAUDE_PLUGIN_ROOT}/config/parallax.yaml` (which engines the chosen pipeline will use).
6. Existing project guidance: `AGENTS.md`, `CLAUDE.md`, README, package files, tests.

## Pipeline selection

Choose exactly one pipeline (each is a skill; resolve its engines from the named `config/parallax.yaml` key).

### `dev` — solo build (config key `quick`)

Use when all are true: one-file or very small change · low-risk · no architecture change · no unclear spec · no external review needed · user did not ask for multi-model review. No Codex, no Grok.

### `team-dev` — team build (config key `team`) — **default**

Use when the task is substantial but ordinary: a feature, a refactor, a bug fix with nontrivial surface, a clean-scope rewrite, or "build something." Codex required; Grok not required. If the task wants extra scrutiny and Grok is available, add Grok review lanes (the old `panel`); if it needs a full plan panel, escalate to `ultra-dev`.

### `ultra-dev` — ultra build (config key `ultra`)

Use only when high-stakes or structurally large: major architecture change, multi-module rewrite, migration, security-sensitive implementation, financial/trading-critical logic, correctness-critical algorithm, or the user explicitly asks for max effort / ultra / full panel. Requires Codex; Grok lanes drop and it degrades if Grok is absent (say so).

### `review` — read-only review (config key `review-only`)

Use when the user asks to review, audit, critique, debug, inspect, or assess existing code without requesting edits. Do not edit unless the user explicitly approves fixes.

> Single-engine asks are separate commands, not router choices: `/plx:claude`, `/plx:codex`, `/plx:grok` bypass the pipeline entirely.

## Preflight policy

Preflight requirements follow the **engines actually used by the selected pipeline in `config/parallax.yaml`**, not a fixed list. The same CLI/auth backs an engine's `-ro` and `-rw` wrappers, so the read-only probe is a sufficient availability check for a non-Claude writer.

After choosing a candidate pipeline (default-config flags shown):

- `dev`: no external preflight (unless the config sets a non-Claude `code` writer — then require that engine).
- `team-dev`: `${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh --repo <repo> --require-codex`.
- `ultra-dev`: `${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh --repo <repo> --require-codex --optional-grok`.
- `review`: preflight with `--repo <repo>` only for the engines the selected review lanes need.

If a required engine is unavailable, stop with a clear message. If an optional engine is unavailable, drop that lane and continue.

`<repo>` is the absolute repo path printed by deterministic intake.

## Execute

Having selected a pipeline, run the **"## Pipeline" section of `${CLAUDE_PLUGIN_ROOT}/skills/<chosen>/SKILL.md`** in order. You have already done intake — skip the target skill's intake line, but still run its preflight. Resolve engines from `config/parallax.yaml` and follow `lib/pipeline.md` for binding, subagent injection, and shared rules.

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
