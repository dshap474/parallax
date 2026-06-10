# Architecture

Parallax is a router-first, role-based coding workflow for Claude Code.

The public surface is one skill:

```text
/plx:auto <task>
```

Internally, the router selects one **pipeline** (each is a skill):

```text
dev (solo) | team-dev | ultra-dev | review
```

## Core Idea

Most AI coding workflows let one model write and review end to end. Parallax separates writing from review:

- **Claude writes** through the orchestrator (dev/team-dev) or a fresh `plx:claude-worker` subagent (delegating pipelines).
- **Codex and Grok review read-only** through `plx:codex-reviewer` / `plx:grok-reviewer` subagents that wrap the CLI scripts.
- **Fresh `plx:claude-reviewer` lanes** can provide additional read-only review.

Each lane is injected as an engine-named subagent (`plx:<engine>-reviewer` / `-worker`) resolved from `config/parallax.yaml`, so the TUI shows which engine ran it.

The orchestrator synthesizes plans and findings, then applies fixes in one coherent pass.

## Role-Based Pipeline

The shared pipeline is still engine-agnostic:

```text
Plan -> Plan-review -> Code -> Refine -> Review -> Fix
```

| Stage | Role | Edits repo? |
|---|---|---|
| Plan | orchestrator | no |
| Plan-review | read-only reviewer | no |
| Code | worker or orchestrator | yes |
| Refine | orchestrator | yes |
| Review | read-only reviewers | no |
| Fix | orchestrator | yes |

`skills/auto/SKILL.md` selects the pipeline (its selection logic is written out inline). **Each skill IS its pipeline, written out in full** — the ordered steps, lane briefs, prompt templates, engine invocation rules, and neutral-context rule all live inline in that skill's `SKILL.md`. There are no shared prompt files and no script injection; the only external inputs are `config/parallax.yaml` (role→engine bindings, resolved before executing) and the engine API tools in `bin/` (on the Bash PATH while the plugin is enabled, so skills and agents invoke them by bare name).

## Pipelines

Each pipeline is a fully self-contained skill. The router auto-selects among the four below; explicit `/plx:*` commands force any pipeline, including the plan/review tiers (see [`COMMANDS.md`](COMMANDS.md)).

| Pipeline (skill) | Config key | Purpose | External engines |
|---|---|---|---|
| `dev` | `quick` | small safe edits, no review | none |
| `team-dev` | `team` | default substantial work | Codex |
| `ultra-dev` | `ultra` | major/high-risk changes; plan panel + full review | Codex + optional Grok |
| `review` | `review-only` | audit/debug/critique without edits | selected read-only lanes |
| `plan` | — | solo plan + per-task specs, no build | none |
| `team-plan` | `team-plan` | plan panel (Claude+Codex) → synthesized plan | Codex |
| `ultra-plan` | `ultra-plan` | Socratic interview → 3-engine plan panel → staged plan | Codex + optional Grok |
| `team-review` | `team-review` | debug+correctness audit across Codex+Claude | Codex |
| `ultra-review` | `ultra-review` | full 3-engine panel across all review lanes | Codex + optional Grok |

(For "team + extra scrutiny", add Grok to the team review lists in `config/parallax.yaml` — the old `panel`.)

## Safety Model

- Role determines repo access, not engine. Review and plan lanes are read-only for every engine; only the writer (`code`) role edits the repo, and exactly one engine fills it per pipeline.
- Codex/Grok review calls go through `bin/plx-codex-ro` / `bin/plx-grok-ro` (read-only).
- A non-Claude writer (when `config/parallax.yaml` sets `code: codex`/`grok`) goes through `bin/plx-codex-rw` (scoped `workspace-write`) / `bin/plx-grok-rw` (kernel `workspace` sandbox) — edits confined to the target repo, never full-access. Default config keeps Claude the sole writer.
- Review prompts are assembled with neutral context only.
- Parallax does not create `.parallax/`, `.parallax/cache`, or `.parallax/runs`.
- Runtime prompts, logs, and external model outputs are chat context or temp files that are cleaned up before commands return.

## Hooks Policy

Parallax v0.1 does not install hooks.

Safety comes from:

- one public `plx` skill
- a deterministic engine API (`bin/plx-*`): uniform flags, uniform exit codes (0 ok · 1 engine failure · 2 usage error · 3 auth needed), `--help` manuals, safety flags pinned in code
- read-only Codex/Grok review invocations; scoped-write tools for an opt-in non-Claude writer
- no repo-local runtime state
- only the `code` role writes (Claude by default)

A future version may add a `PreToolUse` safety hook to block raw unsafe `codex` or `grok` commands, but that is intentionally out of scope for v0.1.

## References

`base-prompts/` holds the base prompt texts (plan, code, refine, debug, correctness, synthesis, coding-spec-template) as an **editable reference library only** — nothing reads it at runtime. Each skill carries its own inline copy; editing a base prompt does not change the skills.
