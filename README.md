# Parallax

Multi-model coding-agent orchestration for Claude Code.

Claude writes. Codex and Grok review read-only. One public skill, `llx`, routes each task to the smallest workflow that gives enough assurance.

## Install

```text
/plugin marketplace add dshap474/parallax
/plugin install parallax@parallax-marketplace
/reload-plugins
```

Then, in any repo:

```text
/parallax:llx add a lollipop chart type to the plotting library
```

## What happens

`llx` performs deterministic intake, then selects one mode:

| Mode | Use case | Engines |
|---|---|---|
| `quick` | small safe edits | Claude only |
| `team` | default build workflow | Claude + Codex + Claude reviewer |
| `panel` | extra review | Claude + Codex + optional Grok |
| `ultra` | major/high-risk changes | Claude + Codex + Grok panel |
| `review-only` | reviews, audits, debugging without edits | read-only reviewers |

Every reviewer is fresh, neutral-context, and read-only. All run artifacts stay in `.parallax/runs/<run-id>/`.

## Requirements

Parallax orchestrates external model CLIs you install and authenticate yourself. It does not bundle, host, or proxy any model.

| Tier | Install | Enables |
|---|---|---|
| Codex | `codex` CLI + auth | `llx` team mode |
| Grok | `grok` CLI + auth | `llx` panel and ultra modes |

Quick mode can run without Codex. Team mode requires Codex. Panel degrades if Grok is missing. Ultra requires Codex and Grok unless you explicitly degrade. See [`docs/REQUIREMENTS.md`](docs/REQUIREMENTS.md).

## Architecture

Parallax keeps a role-based pipeline:

```text
Plan -> Plan-review -> Code -> Refine -> Review -> Fix
```

The public UX is one router skill. Internally, modes choose the workflow topology. The core safety model stays constant: Claude is the sole writer; Codex and Grok are invoked only through bundled read-only wrapper scripts. See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Repo layout

```text
parallax/
├── .claude-plugin/{plugin.json, marketplace.json}
├── skills/llx/{SKILL.md, router.md, modes.md, references/, scripts/}
├── agents/{reviewer.md, worker.md}
├── docs/{ARCHITECTURE, REQUIREMENTS, BENCHMARK, CONTRIBUTING, SPEC}.md
├── _source/references/
└── scripts/sync-references.sh
```

`_source/references/` is canonical. Run `bash scripts/sync-references.sh` after editing references so `skills/llx/references/` stays in sync.

## Status

v0.1.0 draft. The package is structured around `/parallax:llx`; clean install and live smoke checks are the remaining release gates.

## License

MIT — see [`LICENSE`](LICENSE).
