# Parallax

Multi-model coding-agent orchestration for Claude Code.

By default Claude writes and Codex reviews read-only (Grok joins as a read-only reviewer in `ultra-dev`). The router skill `/plx:auto` reads each task and picks the smallest workflow that gives enough assurance; explicit `/plx:*` commands force a specific workflow or single engine (see [`docs/COMMANDS.md`](docs/COMMANDS.md)). Which engine fills each pipeline role per mode is configurable in [`config/parallax.yaml`](config/parallax.yaml) — any of Claude, Codex, or Grok can be the writer (non-Claude writers edit inside a kernel-enforced per-repo sandbox).

## Install

```text
/plugin marketplace add dshap474/parallax
/plugin install plx@parallax-marketplace
/reload-plugins
```

Then, in any repo:

```text
/plx:auto add a lollipop chart type to the plotting library
```

## What happens

`/plx:auto` establishes repo ground truth (Bootstrap), then selects one pipeline (each is a fully self-contained skill — its steps, lane briefs, and engine invocations are all written out in its own `SKILL.md`):

| Pipeline | Use case | Engines |
|---|---|---|
| `dev` | small safe edits, no review | Claude only |
| `team-dev` | default build workflow | Claude + Codex + Claude reviewer |
| `ultra-dev` | major/high-risk changes | Claude + Codex + Grok (plan panel + full review) |
| `review` | reviews, audits, debugging without edits | read-only reviewers |

Every reviewer is fresh, neutral-context, and read-only — regardless of which engine fills the lane. Parallax does not write repo-local runtime state; temporary prompt/output files live only in shell temp directories and are cleaned up before commands return.

### Configuring engines

`config/parallax.yaml` binds each pipeline role to an engine, per pipeline. The shipped defaults reproduce the table above. Edit a `code` value to change which engine *writes* in that pipeline (`claude`, `codex`, or `grok`); edit the review-lane lists to change which engines review (e.g. add `grok` to `team`'s lists for the old "panel" behavior). Review and plan lanes are always read-only no matter the engine — only the `code` role writes, and only it can be a non-Claude engine.

## Requirements

Parallax orchestrates external model CLIs you install and authenticate yourself. It does not bundle, host, or proxy any model.

| Tier | Install | Enables |
|---|---|---|
| Codex | `codex` CLI + auth | `team-dev` (and Codex review lanes) |
| Grok | `grok` CLI + auth | `ultra-dev` Grok lanes |

`dev` runs without Codex. `team-dev` requires Codex. `ultra-dev` requires Codex and degrades (drops Grok lanes) if Grok is missing. See [`docs/REQUIREMENTS.md`](docs/REQUIREMENTS.md).

## Architecture

Parallax keeps a role-based pipeline:

```text
Plan -> Plan-review -> Code -> Refine -> Review -> Fix
```

The public UX is one router skill. Internally, modes choose the workflow topology. The core safety model: review and plan lanes are read-only for every engine, invoked only through the plugin's read-only engine tools (`plx-codex-ro` / `plx-grok-ro`, on PATH from `bin/`); only the writer (`code`) role edits the repo, and a non-Claude writer goes through a scoped-write tool (`plx-codex-rw` / `plx-grok-rw`) that confines edits to the target repo. Default config keeps Claude the sole writer. See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Repo layout

```text
parallax/
├── .claude-plugin/{plugin.json, marketplace.json}
├── skills/       # one dir per command; each SKILL.md is fully self-contained
├── config/       # parallax.yaml — engine-per-role bindings
├── bin/          # engine API on PATH (plx-codex-ro/-rw, plx-grok-ro/-rw, plx-preflight, plx-config, plx-skill)
├── base-prompts/ # reference prompt library (plan, code, refine, debug, …) — storage only, not loaded at runtime
├── templates/
├── agents/
└── docs/{ARCHITECTURE, REQUIREMENTS, BENCHMARK, CONTRIBUTING, SPEC}.md
```

Each `skills/<name>/SKILL.md` carries its entire pipeline — lane briefs, prompt templates, engine invocations — with no pointers to other prompt files and no script injection. `base-prompts/` holds the base prompt texts as an editable reference library; changing one does not change the skills (update the skill by hand).

## Status

v0.1.0 draft. The package is structured around `/plx:auto`; clean install and live smoke checks are the remaining release gates.

## License

MIT — see [`LICENSE`](LICENSE).
