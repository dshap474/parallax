# Parallax

Multi-model coding-agent orchestration for Claude Code.

By default Claude writes and Codex and Grok review read-only. One public skill, `plx`, routes each task to the smallest workflow that gives enough assurance. Which engine fills each pipeline role per mode is configurable in [`skills/plx/parallax.yaml`](skills/plx/parallax.yaml).

## Install

```text
/plugin marketplace add dshap474/parallax
/plugin install parallax@parallax-marketplace
/reload-plugins
```

Then, in any repo:

```text
/parallax:plx add a lollipop chart type to the plotting library
```

## What happens

`plx` performs deterministic intake, then selects one mode:

| Mode | Use case | Engines |
|---|---|---|
| `quick` | small safe edits | Claude only |
| `team` | default build workflow | Claude + Codex + Claude reviewer |
| `panel` | extra review | Claude + Codex + optional Grok |
| `ultra` | major/high-risk changes | Claude + Codex + Grok panel |
| `review-only` | reviews, audits, debugging without edits | read-only reviewers |

Every reviewer is fresh, neutral-context, and read-only — regardless of which engine fills the lane. Parallax does not write repo-local runtime state; temporary prompt/output files live only in shell temp directories and are cleaned up before commands return.

### Configuring engines

`skills/plx/parallax.yaml` binds each pipeline role to an engine, per mode. The shipped defaults reproduce the table above. Edit a `code` value to change which engine *writes* in that mode (`claude`, `codex`, or `grok`); edit the review-lane lists to change which engines review. Review and plan lanes are always read-only no matter the engine — only the `code` role writes, and only it can be a non-Claude engine.

## Requirements

Parallax orchestrates external model CLIs you install and authenticate yourself. It does not bundle, host, or proxy any model.

| Tier | Install | Enables |
|---|---|---|
| Codex | `codex` CLI + auth | `plx` team mode |
| Grok | `grok` CLI + auth | `plx` panel and ultra modes |

Quick mode can run without Codex. Team mode requires Codex. Panel degrades if Grok is missing. Ultra requires Codex and Grok unless you explicitly degrade. See [`docs/REQUIREMENTS.md`](docs/REQUIREMENTS.md).

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
├── skills/plx/{SKILL.md, router.md, modes.md, parallax.yaml, references/, scripts/}
├── agents/{reviewer.md, worker.md}
└── docs/{ARCHITECTURE, REQUIREMENTS, BENCHMARK, CONTRIBUTING, SPEC}.md
```

`skills/plx/references/` contains the runtime reference briefs. Edit those files directly.

## Status

v0.1.0 draft. The package is structured around `/parallax:plx`; clean install and live smoke checks are the remaining release gates.

## License

MIT — see [`LICENSE`](LICENSE).
