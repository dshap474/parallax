# Polyphony

**A multi-model build pipeline for [Claude Code](https://docs.claude.com/en/docs/claude-code).**
Many independent voices, one composition: Claude orchestrates and writes the code, while
Codex and Grok review it read-only at every gate. The orchestrator merges their findings
and applies the fixes.

> **The thesis — the engine that *reviews* matters more than the one that *writes*.** In
> our own benchmark, **Codex reviewing Claude-authored code caught a real logic bug Claude's
> own review missed** (a truthiness check that silently returned an empty result). Multiple
> independent models, each blind to the others, surface defects a single model talks itself
> out of. See [`docs/BENCHMARK.md`](docs/BENCHMARK.md).

## What you get

Two user-invoked skills and the two subagents they drive:

| Skill | What it does | Needs |
|---|---|---|
| **`/polyphony:team-dev`** | Everyday build pipeline. Claude plans → fresh worker writes → Claude refines → Codex + Claude review → Claude fixes. | `codex` CLI |
| **`/polyphony:ultra-dev`** | Heavyweight panel: a 5-model plan panel and a 9-reviewer panel. Most coverage, highest cost. | `codex` + `grok` |

Subagents `polyphony:reviewer` (read-only) and `polyphony:worker` (write) ship with the
plugin, so the pipeline is self-contained.

## Install

```text
/plugin marketplace add dshap474/polyphony
/plugin install polyphony@polyphony-marketplace
/reload-plugins
```

Then, in any repo:

```text
/polyphony:team-dev add a lollipop chart type to the plotting library
```

## Requirements

Polyphony orchestrates **external model CLIs you install and authenticate yourself** — it
doesn't bundle or host any model. `team-dev` needs only the **`codex`** CLI; the optional
Grok tier (`ultra-dev`, and `team-dev`'s optional review panel) adds **`grok`**. Full
setup, auth, and hardening notes: [`docs/REQUIREMENTS.md`](docs/REQUIREMENTS.md).

| Tier | Install | Enables |
|---|---|---|
| **Required** | `codex` CLI + auth | `team-dev` (full cross-model review) |
| **Optional (Grok)** | + `grok` CLI + auth | `ultra-dev`, `team-dev`'s Grok panel |

A preflight step probes what's available and **degrades gracefully** — a missing engine
drops its review lane, it doesn't crash the run.

## How it works

A shared, engine-agnostic **6-stage pipeline** (Plan → Plan-review → Code → Refine →
Review → Fix). Each skill is a **combo**: a roster mapping pipeline *roles* to *engines*.
Swapping a model is a one-line roster change; the pipeline logic never moves. Details:
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

```
Plan ─▶ Plan-review ─▶ Code ─▶ Refine ─▶ Review (Debug ∥ Correctness) ─▶ Fix
(Claude)  (Codex)     (worker) (Claude)   (Codex + Claude, read-only)    (Claude)
```

Every reviewer is **fresh, neutral-context, and read-only** — it never saw the code being
written, so its judgment is independent. Claude is the only engine that edits.

## Repo layout

```
polyphony/
├── .claude-plugin/{plugin.json, marketplace.json}
├── skills/{team-dev, ultra-dev}/{SKILL.md, references/}
├── agents/{reviewer.md, worker.md}
├── docs/{ARCHITECTURE, REQUIREMENTS, BENCHMARK, CONTRIBUTING}.md
├── _source/references/        # canonical briefs; synced into each skill
└── scripts/sync-references.sh
```

Each skill carries its **own copy** of the reference briefs (a Claude Code limitation makes
a single shared copy unreliable at runtime). They're kept DRY from `_source/references/`
via `scripts/sync-references.sh` — run it after editing a brief. See
[`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md).

## Status

**v0.1.0.** `team-dev` runs on `codex` alone; `ultra-dev` and `team-dev`'s optional review
panel add `grok`. All engines (`codex-ro`, `composer-ro`) are verified read-only.

## License

MIT — see [`LICENSE`](LICENSE).
