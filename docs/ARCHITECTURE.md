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

`skills/auto/router.md` selects the pipeline. **Each skill owns its pipeline** — the ordered block composition lives in that skill's "## Pipeline" section. `lib/pipeline.md` holds the shared grammar (role invariants, engine binding, subagent injection, neutral-context rule); `lib/engines.md` defines engine invocation rules; `prompts/` holds the reusable step blocks; `config/parallax.yaml` binds each role to an engine per pipeline. The orchestrator resolves the binding before executing.

## Pipelines

Each pipeline is a skill that composes prompt blocks in order. The router auto-selects one; explicit `/plx:*` commands force one (see [`COMMANDS.md`](COMMANDS.md)).

| Pipeline (skill) | Config key | Purpose | External engines |
|---|---|---|---|
| `dev` | `quick` | small safe edits, no review | none |
| `team-dev` | `team` | default substantial work | Codex |
| `ultra-dev` | `ultra` | major/high-risk changes; plan panel + full review | Codex + optional Grok |
| `review` | `review-only` | audit/debug/critique without edits | selected read-only lanes |

(For "team + extra scrutiny", add Grok to the team review lists in `config/parallax.yaml` — the old `panel`.)

## Safety Model

- Role determines repo access, not engine. Review and plan lanes are read-only for every engine; only the writer (`code`) role edits the repo, and exactly one engine fills it per pipeline.
- Codex/Grok review calls go through `scripts/codex-ro.sh` / `grok-ro.sh` (read-only).
- A non-Claude writer (when `config/parallax.yaml` sets `code: codex`/`grok`) goes through `scripts/codex-rw.sh` (scoped `workspace-write`) / `grok-rw.sh` (`acceptEdits`) — edits confined to the target repo, never full-access/bypass. Default config keeps Claude the sole writer.
- Review prompts are assembled with neutral context only.
- Parallax does not create `.parallax/`, `.parallax/cache`, or `.parallax/runs`.
- Runtime prompts, logs, and external model outputs are chat context or temp files that are cleaned up before commands return.

## Hooks Policy

Parallax v0.1 does not install hooks.

Safety comes from:

- one public `plx` skill
- deterministic wrapper scripts
- read-only Codex/Grok review invocations; scoped-write wrappers for an opt-in non-Claude writer
- no repo-local runtime state
- only the `code` role writes (Claude by default)

A future version may add a `PreToolUse` safety hook to block raw unsafe `codex` or `grok` commands, but that is intentionally out of scope for v0.1.

## References

The review/spec briefs live in `prompts/` and the shared reference docs (`engines.md`, `pipeline.md`) in `lib/` — the root-level paths the installed skill reads at runtime.
