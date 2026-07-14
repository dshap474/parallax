# Parallax — Package Specification

Status: v0.4.0

## Purpose

Parallax packages a multi-model coding workflow as an installable Claude Code plugin. Its entry points are three stage skills, their composition, and autonomous-goal prep:

```text
plan | build | review   →   dev   ·   goal-spec
```

Each pipeline establishes repo ground truth (Bootstrap), then runs its steps. Explicit `/plx:*` commands run a stage, the composition, or hand a task to a single engine (see `docs/COMMANDS.md`).

The orchestrator is Claude (Fable). There are **no subagents**: the orchestrator drives Codex, Grok, and Claude headless itself through one wrapper (`bin/plx-engine`), launching every lane as background Bash with out/log files. Lane rubrics ship in `prompts/` and are injected at runtime by `--rubric` name. The orchestrator spends its own intelligence at plan authoring, review synthesis, and the final gate; all bulk work runs in external engine lanes. Config values are the **floor shape**: the orchestrator sizes every run per the shipped judgment doc (`prompts/engines.md`) — no plan critic, implementation only, or implementation + system; 1–N file-disjoint workers; and 1–6 review lanes — then declares the sizing before launch. Confirmed review findings are fixed automatically by cheap targeted fix lanes; only genuinely uncertain calls go to the user. Critic, planner, and review lanes are read-only; writers follow one-writer-per-disjoint-path-set. Skills never commit.

## What ships

- 5 pipeline skills, each **self-contained** (steps, lane briefs, and engine invocations written out inline — no path pointers, no `${CLAUDE_PLUGIN_ROOT}`, no script injection; external inputs arrive only through `bin/` tools: `plx-config` bindings, `plx-skill --ref` templates, `plx-engine --rubric` rubric injection): `plx:plan`, `plx:build`, `plx:review` (review + auto-fix), `plx:dev` (the composition), `plx:goal-spec` (interview-locked goal planning)
- 2 single-engine passthroughs: `plx:codex`, `plx:grok` (no `plx:claude` — the orchestrator *is* Claude); 1 setup skill: `plx:init`
- Lane rubrics in `prompts/`: `reviewer-correctness`, `reviewer-cleanup`, `reviewer-structural`, `planner`, `plan-critic-implementation`, `plan-critic-system`, `worker` (serves build workers and fix lanes) — one deduped engine-agnostic file per lane — plus `engines.md`, the judgment doc (model cost/intelligence/taste rankings, sizing ladder, writer rules)
- 1 default engine-binding config (`config/parallax.yaml`), keyed by pipeline: `plan`, `build`, `review`, `dev`, `goal-spec`
- A deterministic engine API in `bin/` (on the Bash PATH while the plugin is enabled): `plx-engine` (the unified wrapper: `--engine codex|grok|claude --mode ro|rw --repo --prompt-file [--rubric] [--effort] [--model] (--stdout | --out --log)`, plus `--print-rubric <name>`), `plx-preflight` (probes any engine), `plx-config`, `plx-skill`, `plx-link-claude` — uniform exit codes (0 ok · 1 engine failure · 2 usage error · 3 auth needed) and `--help` manuals

## Target tree

```text
.
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── skills/
│   ├── plan/SKILL.md       # plan stage (author + sized red-team)
│   ├── build/SKILL.md      # build stage (1–N file-disjoint writer lanes)
│   ├── review/SKILL.md     # review stage (sized lanes + auto-fix)
│   ├── dev/SKILL.md        # the composition (plan → build → review → gate)
│   ├── goal-spec/SKILL.md  # interview-locked goal planning
│   ├── codex/SKILL.md      # single-engine passthrough
│   ├── grok/SKILL.md       # single-engine passthrough
│   └── init/SKILL.md       # project bootstrap
├── prompts/            # lane rubrics + engines.md judgment doc
├── config/             # parallax.yaml — default engine bindings
├── bin/                # engine API on PATH (plx-* tools)
├── docs/
├── tests/
├── LICENSE
└── README.md
```

## Plugin identity

`plugin.json` uses:

```json
{
  "name": "plx",
  "version": "0.4.0"
}
```

`marketplace.json` uses:

```json
{
  "name": "parallax-marketplace"
}
```

Each skill path `skills/<name>/SKILL.md` maps to `/plx:<name>` (e.g. `skills/dev/SKILL.md` → `/plx:dev`).

## Runtime rules

- Each pipeline is a **self-contained skill**: its ordered steps, lane briefs, and engine invocations are all inline in its `SKILL.md`. External inputs arrive only through `bin/` tools invoked by bare name: engine bindings via `plx-config`, shared templates via `plx-skill --ref`, rubrics via `plx-engine --rubric <name>`.
- Skills contain no `!`-command injection, no `${CLAUDE_PLUGIN_ROOT}`, and no pointers into `prompts/`, `lib/`, or `scripts/` — rubrics are referenced by bare name only; `plx-engine` resolves the files relative to itself.
- All engine execution goes through `plx-engine`. Skills never hand-construct raw `codex` / `grok` / `claude -p` commands. Safety is pinned inside the wrapper per engine: codex `--ignore-user-config --ephemeral` + `read-only`/`workspace-write` sandbox; grok kernel sandbox `read-only`/`workspace`; claude non-bare `-p` + `dontAsk`/`acceptEdits` with scoped tool allowlists. Wrappers never use `danger-full-access`, `--dangerously-bypass-approvals-and-sandbox`, or `--yolo`.
- Lanes run as background Bash (`run_in_background`) with `--out`/`--log` files; independent lanes launch in one message.
- No hooks. No repo-local runtime state — never create `.parallax/`, `.parallax/cache`, or `.parallax/runs`.
- The orchestrator establishes repo ground truth itself (Bootstrap: `git rev-parse --show-toplevel`, `git status --short`).
- Preflight and wrappers use shell temp directories only and clean them up before returning.
- Plan authoring, review synthesis, and the final gate are always the orchestrator. Critic/planner/review lanes are always `--mode ro`. Writers (build workers, fix lanes) follow **one writer per disjoint path set**: parallel rw lanes only on non-overlapping files, each brief naming the paths it owns; verification after all writers land.
- Sizing is declared before launch: the orchestrator prints its chosen shape (critics × workers × review lanes × effort) as a one-line veto point.
- Standalone `/plx:plan` pins both plan-critic dimensions to Codex `gpt-5.6-sol` at `xhigh` for every non-small plan; `/plx:dev` retains proportional plan sizing.
- **Skills never commit or publish** — version control follows the target repo's own agent instructions.
- Final results are returned in chat, not written to a results file.

## Contracts

The shapes that flow between stages:

1. **Brief headers** — every brief file opens with the section header its rubric expects: `## Review brief` (reviewer-*), `## Task brief` (planner), `## Draft plan` (plan-critic-*), `## Spec` (worker — both build specs and fix briefs).
2. **Planning Brief** — recommended design + steelman, alternatives rejected, repo facts, constraints/invariants, suggested success criteria, validation, risks. Output of each planner lane (goal-spec); Fable arbitrates and authors the final plan itself.
3. **Buildout report** — every file touched, per-file summary, coding decisions, verification (commands + results), blockers/skips. Summaries only, never code bodies. Output of every writer lane; cross-checked against `git status` vs the run's starting snapshot.
4. **Review brief** — repo, files touched (from git ground truth), what was implemented and why, spec pointer. Written by the orchestrator; identical for every lane, no steer.
5. **Finding Schema** — id, severity, file:line, what breaks, minimal fix, confidence. Output of every review lane; input to the orchestrator's synthesis.
6. **Fix brief** — a `## Spec` header + the confirmed findings verbatim + "fix exactly these; change nothing else." Input to the cheap fix lanes.
7. **Finding disposition** — per surviving finding: fixed / asked (user confirmation) / won't-fix (with reason) / residual.

## Acceptance criteria

These mirror the deterministic checks run by `tests/run.sh`.

### File structure

```bash
test -f skills/plan/SKILL.md
test -f skills/build/SKILL.md
test -f skills/review/SKILL.md
test -f skills/dev/SKILL.md
test -f skills/goal-spec/SKILL.md
test -f config/parallax.yaml
test -d bin
test -d prompts
```

### Engine API (bin/)

```bash
test -x bin/plx-engine
test -x bin/plx-preflight
test -x bin/plx-config
test -x bin/plx-skill
test -x bin/plx-link-claude
bin/plx-engine --help | grep -q "Usage:"
bin/plx-config | grep -q "pipelines:"
```

### Rubrics

```bash
for r in reviewer-correctness reviewer-cleanup reviewer-structural planner plan-critic-implementation plan-critic-system worker engines; do
  test -s "prompts/$r.md"
done
```

Every `--rubric <name>` referenced by a skill resolves to `prompts/<name>.md` (enforced by `tests/check-plugin.sh`).

### No runtime state

```bash
test ! -d .parallax
```

### Self-contained skills

No skill points at external prompt files, plugin-root paths, or uses `!`-command injection:

```bash
! grep -rE 'lib/(pipeline|engines)\.md|prompts/|scripts/|router\.md' skills/*/SKILL.md
! grep -r 'CLAUDE_PLUGIN_ROOT' skills/
```

### Runtime tool safety

Raw engine CLIs appear only inside `bin/plx-engine` — never in skills or ad-hoc scripts:

```bash
! grep -R "codex exec" . --exclude-dir=.git --exclude='plx-engine' --exclude='*.md'
! grep -R "grok --"   . --exclude-dir=.git --exclude='plx-engine' --exclude='*.md'
```

### No subagent references

```bash
! grep -rE 'plx:(claude|codex|grok)-[a-z-]+' skills/ config/
! grep -rEi 'use subagents|spawn (a |an )?subagent' skills/
test ! -d agents
```

### Plugin namespace

After local install:

```text
/plugin marketplace add ./
/plugin install plx@parallax-marketplace
/reload-plugins
```

Expected: `/plx:plan`, `/plx:build`, `/plx:review`, `/plx:dev`, `/plx:goal-spec`, `/plx:codex`, `/plx:grok`, `/plx:init` appear (no `/plx:claude`); nothing appears in `/agents` under the `plx:` namespace.

### Smoke tests

Preflight smoke (model-free):

```bash
bin/plx-preflight --repo "$(pwd)"
test ! -d .parallax
```

Engine probe (spends a tiny model call each, env-dependent):

```bash
bin/plx-preflight --repo "$(pwd)" --require-codex --require-claude --optional-grok
```

Expected: each required engine passes (or reports a clear auth/missing error with exit code 3); no empty engine output treated as success; no `.parallax/` directory is created.
