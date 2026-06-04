# Parallax — Package Specification

Status: draft v0.1

## Purpose

Parallax packages a multi-model coding workflow as an installable Claude Code plugin. It exposes one public skill:

```text
/parallax:llx <task>
```

`llx` performs deterministic intake, then routes the task to one internal mode:

```text
quick | team | panel | ultra | review-only
```

Claude is the only writer. Codex and Grok are read-only reviewers.

## What Ships

- 1 public skill: `llx`
- 2 subagents: `reviewer`, `worker`
- 5 modes: `quick`, `team`, `panel`, `ultra`, `review-only`
- Deterministic scripts for intake, preflight, prompt assembly, output collection, and read-only external reviewers
- Shared reference briefs synced from `_source/references/` into `skills/llx/references/`

## Target Tree

```text
.
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── agents/
│   ├── reviewer.md
│   └── worker.md
├── skills/
│   └── llx/
│       ├── SKILL.md
│       ├── router.md
│       ├── modes.md
│       ├── references/
│       └── scripts/
├── _source/references/
├── scripts/sync-references.sh
├── docs/
├── .gitignore
├── LICENSE
└── README.md
```

## Plugin Identity

`plugin.json` uses:

```json
{
  "name": "parallax",
  "version": "0.1.0"
}
```

`marketplace.json` uses:

```json
{
  "name": "parallax-marketplace"
}
```

The skill path `skills/llx/SKILL.md` maps to `/parallax:llx`.

## Runtime Rules

- No public mode-specific skills.
- No hooks in v0.1.
- No `.parallax/cache`.
- Intake creates an absolute run directory under `<repo>/.parallax/runs/<run-id>/`.
- Do not use `uv run` inside a sandbox.
- Codex execution goes through `skills/llx/scripts/codex-ro.sh`.
- Grok execution goes through `skills/llx/scripts/grok-ro.sh`.
- Review and plan prompts are built with `skills/llx/scripts/make-review-prompt.sh`.
- Every mode writes `results.md` in the run directory.

## Acceptance Criteria

### File Structure

```bash
test -f skills/llx/SKILL.md
test -f skills/llx/router.md
test -f skills/llx/modes.md
test -d skills/llx/references
test -d skills/llx/scripts
test ! -d skills/team-dev
test ! -d skills/ultra-dev
```

### Executable Scripts

```bash
test -x skills/llx/scripts/parallax-intake.sh
test -x skills/llx/scripts/preflight.sh
test -x skills/llx/scripts/codex-ro.sh
test -x skills/llx/scripts/grok-ro.sh
test -x skills/llx/scripts/make-review-prompt.sh
test -x skills/llx/scripts/collect-outputs.sh
```

### Intake

```bash
RUN_DIR="$(skills/llx/scripts/parallax-intake.sh | awk -F': ' '/run_dir:/ {print $2}')"
test "${RUN_DIR:0:1}" = "/"
```

Expected:

```text
<run-dir>/state.env exists
<run-dir>/intake.md exists
printed run_dir
printed codex_present yes/no
printed grok_present yes/no
```

### No Cache

```bash
test ! -d .parallax/cache
```

### Sync References

```bash
bash scripts/sync-references.sh
diff -q _source/references/pipeline.md skills/llx/references/pipeline.md
diff -q _source/references/engines.md skills/llx/references/engines.md
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
/plugin install parallax@parallax-marketplace
/reload-plugins
```

Expected:

```text
/parallax:llx appears
/parallax:team-dev does not appear
/parallax:ultra-dev does not appear
parallax:reviewer appears in /agents
parallax:worker appears in /agents
```

### Smoke Tests

Codex-only team smoke:

```text
/parallax:llx make a small nontrivial change in this repo
```

Expected: `team` mode, Codex preflight passes, Grok absence does not crash, Codex review lanes run read-only, Claude writes/fixes, and `results.md` is written.

Quick mode smoke:

```text
/parallax:llx fix this typo in README
```

Expected: `quick` mode, no Codex call, no Grok call, Claude edits directly, and `results.md` is written.

Ultra degradation smoke without Grok:

```text
/parallax:llx use ultra mode to redesign this module
```

Expected: clear Grok requirement or explicit degradation to panel/team; no empty Grok output treated as success.

Prompt assembly smoke:

```bash
skills/llx/scripts/make-review-prompt.sh --lane plan --brief skills/llx/references/coding-spec-template.md --artifact README.md --task README.md --out /tmp/parallax-plan-prompt.md
test -s /tmp/parallax-plan-prompt.md
```
