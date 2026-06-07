# Parallax — Package Specification

Status: draft v0.1

## Purpose

Parallax packages a multi-model coding workflow as an installable Claude Code plugin. Its primary entry point is the router skill:

```text
/plx:auto <task>
```

The router (`plx:auto`) performs deterministic intake, then routes the task to one pipeline:

```text
dev | team-dev | ultra-dev | review
```

Explicit `/plx:*` commands can force a specific pipeline or a single engine without routing (see `docs/COMMANDS.md`).

Review and plan lanes are read-only for every engine; only the writer (`code`) role edits the repo. By default the writer is Claude, but `config/parallax.yaml` can bind it to Codex or Grok per pipeline (scoped-write wrappers).

## What Ships

- 1 router skill: `plx:auto` (auto-selects a pipeline)
- Pipeline skills — each composes prompt blocks in order: implemented — `plx:dev`, `plx:team-dev`, `plx:ultra-dev`, `plx:review`; single-engine passthroughs — `plx:claude`, `plx:codex` (`plx:grok` scaffold); scaffolded — `plx:plan`, `plx:team-plan`, `plx:team-review`, `plx:ultra-plan`, `plx:ultra-review`
- 6 subagents: `{claude,codex,grok}-{reviewer,worker}` — `-reviewer` lanes read-only, `-worker` lanes write-capable
- 7 reusable step blocks in `prompts/`: `plan`, `coding-spec-template`, `code`, `refine`, `debug`, `correctness`, `synthesis`
- 1 shared grammar (`lib/pipeline.md`) + 1 engine-per-role config (`config/parallax.yaml`), keyed by pipeline (`quick`, `team`, `ultra`, `review-only`)
- Deterministic scripts for intake, preflight, prompt assembly, read-only external reviewers, and opt-in scoped-write external writers

## Target Tree

```text
.
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── agents/
├── skills/
│   ├── auto/
│   │   ├── SKILL.md
│   │   └── router.md
│   └── …               # pipeline skills (team-dev, ultra-dev, review, dev, …)
├── config/             # parallax.yaml — engine-per-role bindings
├── scripts/            # *.sh helpers + engine wrappers
├── prompts/            # reusable step blocks (plan, code, refine, debug, …)
├── lib/                # pipeline.md (grammar), engines.md
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

- Each pipeline is a skill: its "## Pipeline" section composes `prompts/` blocks in order, with shared grammar in `lib/pipeline.md` and engine bindings in `config/parallax.yaml`. `/plx:auto` routes; `/plx:*` commands force a pipeline.
- No hooks in v0.1.
- No repo-local runtime state.
- Do not create `.parallax/`, `.parallax/cache`, or `.parallax/runs`.
- Intake prints repo metadata to stdout only.
- Preflight and wrappers use shell temp directories only and clean them up before returning.
- Do not use `uv run` inside a sandbox.
- Codex execution goes through `scripts/codex-ro.sh`.
- Grok execution goes through `scripts/grok-ro.sh`.
- Review and plan prompts are built with `scripts/make-review-prompt.sh`.
- Final results are returned in chat, not written to `results.md`.

## Acceptance Criteria

### File Structure

```bash
test -f skills/auto/SKILL.md
test -f skills/auto/router.md
test ! -e skills/auto/modes.md
test -f config/parallax.yaml
test -d scripts
test -d prompts
test -d lib
test -f prompts/plan.md
test -f prompts/code.md
test -f prompts/synthesis.md
test -f lib/pipeline.md
test -d skills/team-dev
test -d skills/ultra-dev
test ! -d skills/auto/references
test ! -d skills/auto/scripts
```

### Executable Scripts

```bash
test -x scripts/parallax-intake.sh
test -x scripts/preflight.sh
test -x scripts/codex-ro.sh
test -x scripts/grok-ro.sh
test -x scripts/make-review-prompt.sh
test ! -e scripts/collect-outputs.sh
```

### Intake

```bash
INTAKE="$(scripts/parallax-intake.sh)"
printf '%s\n' "$INTAKE" | grep -q "repo: /"
printf '%s\n' "$INTAKE" | grep -q "codex_present:"
printf '%s\n' "$INTAKE" | grep -q "grok_present:"
```

Expected:

```text
printed repo
printed codex_present yes/no
printed grok_present yes/no
no files or directories created
```

### No Runtime State

```bash
test ! -d .parallax
```

### Runtime References

```bash
test -f lib/pipeline.md
test -f lib/engines.md
test -f prompts/synthesis.md
```

### Runtime Wrapper Safety

```bash
! grep -R "codex exec" . --exclude-dir=.git --exclude='codex-ro.sh' --exclude='*.md'
! grep -R "grok --" . --exclude-dir=.git --exclude='grok-ro.sh' --exclude='*.md'
```

Expected: no runtime script violations.

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
/plx:team-dev, /plx:ultra-dev, /plx:review, /plx:claude, /plx:codex appear
plx:claude-reviewer / plx:codex-reviewer / plx:grok-reviewer appear in /agents
plx:claude-worker / plx:codex-worker / plx:grok-worker appear in /agents
```

### Smoke Tests

Preflight smoke:

```bash
scripts/preflight.sh --repo "$(pwd)" --require-codex
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

Prompt assembly smoke:

```bash
scripts/make-review-prompt.sh --lane plan --brief prompts/coding-spec-template.md --artifact README.md --task README.md --out /tmp/parallax-plan-prompt.md
test -s /tmp/parallax-plan-prompt.md
scripts/make-review-prompt.sh --lane plan --brief prompts/coding-spec-template.md --artifact README.md --task README.md --stdout >/tmp/parallax-plan-prompt-stdout.md
test -s /tmp/parallax-plan-prompt-stdout.md
```
