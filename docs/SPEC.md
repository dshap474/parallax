# Parallax — Package Specification

Status: draft v0.1

## Purpose

Parallax packages a multi-model coding workflow as an installable Claude Code plugin. Its primary entry point is the router skill:

```text
/plx:auto <task>
```

The router (`plx:auto`) establishes repo ground truth (Bootstrap), then routes the task to one pipeline:

```text
dev | team-dev | ultra-dev | review
```

Explicit `/plx:*` commands can force a specific pipeline or a single engine without routing (see `docs/COMMANDS.md`).

Review and plan lanes are read-only for every engine; only the writer (`code`) role edits the repo. By default the writer is Claude, but `config/parallax.yaml` can bind it to Codex or Grok per pipeline (scoped-write tools).

## What Ships

- 1 router skill: `plx:auto` (auto-selects a pipeline)
- Pipeline skills, each **fully self-contained** (its steps, lane briefs, prompt templates, and engine handoffs are all written out in its own `SKILL.md` — no pointers to other prompt files, no script injection): build — `plx:dev`, `plx:team-dev`, `plx:ultra-dev`; plan — `plx:plan`, `plx:team-plan`, `plx:ultra-plan`; review — `plx:review`, `plx:team-review`, `plx:ultra-review`; single-engine passthroughs — `plx:codex`, `plx:grok` (no `plx:claude` — the orchestrator *is* Claude)
- 6 subagents: `{claude,codex,grok}-{reviewer,worker}` — `-reviewer` lanes read-only, `-worker` lanes write-capable
- 7 base prompts in `base-prompts/` (`plan`, `coding-spec-template`, `code`, `refine`, `debug`, `correctness`, `synthesis`) — a **reference library only**, never loaded at runtime; the skills carry their own copies inline
- 1 engine-per-role config (`config/parallax.yaml`), keyed by pipeline (`quick`, `team`, `ultra`, `review-only`, `team-plan`, `ultra-plan`, `team-review`, `ultra-review`)
- A deterministic engine API in `bin/` (on the Bash PATH while the plugin is enabled): `plx-codex-ro`/`plx-codex-rw`, `plx-grok-ro`/`plx-grok-rw`, `plx-preflight`, `plx-config`, `plx-skill` — uniform flags (`--repo`, `--prompt-file`, `--stdout`), uniform exit codes (0 ok · 1 engine failure · 2 usage error · 3 auth needed), and `--help` manuals

## Target Tree

```text
.
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── agents/
├── skills/
│   ├── auto/SKILL.md   # router (selection logic written out inline)
│   └── …               # pipeline skills (team-dev, ultra-dev, review, dev, …), each self-contained
├── config/             # parallax.yaml — engine-per-role bindings
├── bin/                # engine API on PATH (plx-* tools)
├── base-prompts/       # reference prompt library — storage only, not loaded at runtime
├── templates/
├── docs/
├── .gitignore
├── LICENSE
└── README.md
```

## Plugin Identity

`plugin.json` uses:

```json
{
  "name": "plx",
  "version": "0.1.0"
}
```

`marketplace.json` uses:

```json
{
  "name": "parallax-marketplace"
}
```

The skill path `skills/auto/SKILL.md` maps to `/plx:auto`.

## Runtime Rules

- Each pipeline is a **self-contained skill**: its "## Pipeline" section, lane briefs, prompt templates, and engine invocations are all inline in its `SKILL.md`; only engine bindings come from `config/parallax.yaml`. `/plx:auto` routes; `/plx:*` commands force a pipeline.
- No prompt injection: skills contain no `!`-command injection and no pointers to external prompt files. `base-prompts/` is reference storage only.
- No hooks in v0.1.
- No repo-local runtime state.
- Do not create `.parallax/`, `.parallax/cache`, or `.parallax/runs`.
- The orchestrator establishes repo ground truth itself (Bootstrap: `git rev-parse --show-toplevel`, `git status --short`).
- Preflight and wrappers use shell temp directories only and clean them up before returning.
- Do not use `uv run` inside a sandbox.
- Codex execution goes through `bin/plx-codex-ro` (review) or, when `code: codex`, `bin/plx-codex-rw` (scoped write).
- Grok execution goes through `bin/plx-grok-ro` (review) or, when `code: grok`, `bin/plx-grok-rw` (scoped write).
- Review and plan lane prompts are assembled by the orchestrator from the labeled sections each skill defines inline (Lane / Lane brief / Artifacts / Task / Repo guidance / Output shape).
- Final results are returned in chat, not written to `results.md`.

## Acceptance Criteria

### File Structure

```bash
test -f skills/auto/SKILL.md
test ! -e skills/auto/router.md
test ! -e skills/auto/modes.md
test -f config/parallax.yaml
test -d bin
test ! -d scripts
test -d base-prompts
test ! -d prompts
test ! -d lib
test -f base-prompts/plan.md
test -f base-prompts/code.md
test -f base-prompts/synthesis.md
test -d skills/team-dev
test -d skills/ultra-dev
test ! -d skills/auto/references
test ! -d skills/auto/scripts
```

### Engine API (bin/)

```bash
test -x bin/plx-preflight
test -x bin/plx-codex-ro
test -x bin/plx-codex-rw
test -x bin/plx-grok-ro
test -x bin/plx-grok-rw
test -x bin/plx-config
test -x bin/plx-skill
bin/plx-codex-ro --help | grep -q "Usage:"
bin/plx-config | grep -q "pipelines:"
```

### No Runtime State

```bash
test ! -d .parallax
```

### Self-Contained Skills

No skill points at external prompt files, plugin-root paths, or uses `!`-command injection:

```bash
! grep -rE 'lib/(pipeline|engines)\.md|prompts/|scripts/|router\.md' skills/*/SKILL.md
! grep -r 'CLAUDE_PLUGIN_ROOT' skills/ agents/
```

### Runtime Tool Safety

Raw engine CLIs may appear only inside the engine API tools — the read-only
(`plx-*-ro`) and the scoped-write (`plx-*-rw`) ones — never in skills, agents, or
ad-hoc scripts:

```bash
! grep -R "codex exec" . --exclude-dir=.git --exclude='plx-codex-ro' --exclude='plx-codex-rw' --exclude='*.md'
! grep -R "grok --"   . --exclude-dir=.git --exclude='plx-grok-ro'  --exclude='plx-grok-rw'  --exclude='*.md'
```

Expected: no runtime violations. The scoped-write tools are the only place
besides the read-only tools that may invoke the raw CLI.

### Plugin Namespace

After local install:

```text
/plugin marketplace add ./
/plugin install plx@parallax-marketplace
/reload-plugins
```

Expected:

```text
/plx:auto appears
/plx:team-dev, /plx:ultra-dev, /plx:review, /plx:codex, /plx:grok appear (no /plx:claude)
plx:claude-reviewer / plx:codex-reviewer / plx:grok-reviewer appear in /agents
plx:claude-worker / plx:codex-worker / plx:grok-worker appear in /agents
```

### Smoke Tests

Preflight smoke:

```bash
bin/plx-preflight --repo "$(pwd)" --require-codex
test ! -d .parallax
```

Codex-only team smoke:

```text
/plx:auto make a small nontrivial change in this repo
```

Expected: `team` mode, Codex preflight passes, Grok absence does not crash, Codex review lanes run read-only, Claude writes/fixes, no `.parallax/` directory is created, and final results are returned in chat.

Quick mode smoke:

```text
/plx:auto fix this typo in README
```

Expected: `quick` mode, no Codex call, no Grok call, Claude edits directly, no `.parallax/` directory is created, and final results are returned in chat.

Ultra degradation smoke without Grok:

```text
/plx:auto use ultra mode to redesign this module
```

Expected: clear Grok requirement or explicit degradation to panel/team; no empty Grok output treated as success.
