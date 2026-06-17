# Parallax test environment

A small, deterministic harness for inspecting and smoke-testing the plugin. It does
**not** run a self-improvement loop and does **not** spend model tokens by default —
it checks that the plugin is wired correctly, shows what each skill *would* do, and
exercises the shell scripts in throwaway repos.

## What's here

| File | What it does |
|---|---|
| `run.sh` | Runs the whole deterministic suite (static checks + script smoke) and prints `ALL GREEN` / failures. |
| `check-plugin.sh` | **Static integrity** — no `${CLAUDE_PLUGIN_ROOT}` in skills/agents (bin/ tools are on PATH), every `plx-*` tool a skill/agent names exists in `bin/` and is executable, config keys a skill names exist in `parallax.yaml` (`dev`, `plan`, `review`), referenced `plx:<persona>` subagents have agent files, manifests are valid JSON, skills are self-contained. No model calls. |
| `explain-skill.sh` | **Dry run** — prints what a skill would do: its config key, resolved engine bindings, preflight requirement, its inline sections, and the verbatim `## Pipeline` steps. Nothing executes. |
| `smoke-scripts.sh` | Runs the real shell scripts (`preflight`) against an **isolated tmp repo** built from `fixture/`. Model-free unless `--with-engines`. |
| `fixture/` | A tiny throwaway target repo (a `calc.average()` with an empty-list bug). Copied to `mktemp` per run — never edited in place. |
| `lib.sh` | Shared assert/counter helpers + the isolated-repo builder. |

## Usage

```bash
# Everything deterministic, no engine calls:
bash tests/run.sh

# See what a skill would execute, without running it:
bash tests/explain-skill.sh              # list skills
bash tests/explain-skill.sh dev          # dry-run one
bash tests/explain-skill.sh review

# Just the wiring check, or just the script smoke:
bash tests/check-plugin.sh
bash tests/smoke-scripts.sh

# Also probe codex/grok auth (spends a tiny model call each, env-dependent):
bash tests/smoke-scripts.sh --with-engines
bash tests/run.sh --with-engines
```

## Scope / what this does NOT do

These checks cover the **deterministic** layer: wiring, contracts, and the projected
pipeline. They do **not** run a full skill end-to-end (a real `dev` run spawns
planner/worker/reviewer subagents and edits a repo — that's a behavioral test,
model-driven and non-deterministic).

That behavioral layer now has its own opt-in suite: **`tests/smoke/`** runs the skills
and engine tools for real against throwaway 1-file fixtures and captures the full
transcript of every lane (`bash tests/smoke/run-smoke.sh` for the cheap engine pass,
`--skills` for the full per-skill audit). It spends tokens, so it's separate from the
free suite above. See [`smoke/README.md`](smoke/README.md). The `fixture/` empty-list
bug is shared by both — it's there so a review lane has something real to catch.
