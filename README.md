# Parallax

Multi-model coding-agent orchestration for Claude Code.

By default Claude writes and Codex and Grok review read-only. The router skill `/plx:auto` reads each task and picks the smallest workflow that gives enough assurance; explicit `/plx:*` commands force a specific workflow or single engine (see [`docs/COMMANDS.md`](docs/COMMANDS.md)). Which engine fills each pipeline role per mode is configurable in [`config/parallax.yaml`](config/parallax.yaml).

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

`/plx:auto` performs deterministic intake, then selects one pipeline (each is a skill that composes prompt blocks in order):

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

The public UX is one router skill. Internally, modes choose the workflow topology. The core safety model: review and plan lanes are read-only for every engine, invoked only through the bundled `*-ro.sh` wrappers; only the writer (`code`) role edits the repo, and a non-Claude writer goes through a scoped-write wrapper (`*-rw.sh`) that confines edits to the target repo. Default config keeps Claude the sole writer. See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Repo layout

```text
parallax/
├── .claude-plugin/{plugin.json, marketplace.json}
├── skills/auto/{SKILL.md, router.md}   # router; siblings are pipeline skills (team-dev, …)
├── config/       # parallax.yaml — engine-per-role bindings
├── scripts/      # *.sh helpers + engine wrappers
├── prompts/      # reusable step blocks (plan, code, refine, debug, …)
├── lib/          # pipeline.md (grammar), engines.md
├── templates/
├── agents/
└── docs/{ARCHITECTURE, REQUIREMENTS, BENCHMARK, CONTRIBUTING, SPEC}.md
```

`prompts/` contains the runtime review/spec briefs and `lib/` the shared reference docs. Edit those files directly.

## Status

v0.1.0 draft. The package is structured around `/plx:auto`; clean install and live smoke checks are the remaining release gates.

## License

MIT — see [`LICENSE`](LICENSE).
