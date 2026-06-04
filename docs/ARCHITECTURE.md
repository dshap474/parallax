# Architecture

Parallax is a router-first, role-based coding workflow for Claude Code.

The public surface is one skill:

```text
/parallax:llx <task>
```

Internally, `llx` selects a mode:

```text
quick | team | panel | ultra | review-only
```

## Core Idea

Most AI coding workflows let one model write and review end to end. Parallax separates writing from review:

- **Claude writes** through the orchestrator or a fresh `worker` subagent.
- **Codex and Grok review read-only** through wrapper scripts.
- **Fresh Claude reviewers** can provide additional read-only review lanes.

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

`skills/llx/router.md` chooses the mode. `skills/llx/modes.md` defines the workflow topology. `skills/llx/references/engines.md` defines engine invocation rules.

## Modes

| Mode | Purpose | External engines |
|---|---|---|
| `quick` | small safe edits | none |
| `team` | default substantial work | Codex |
| `panel` | extra scrutiny | Codex + optional Grok |
| `ultra` | major/high-risk changes | Codex + Grok |
| `review-only` | audit/debug/critique without edits | selected read-only lanes |

## Safety Model

- Claude is the only writer.
- Codex calls go through `skills/llx/scripts/codex-ro.sh`.
- Grok calls go through `skills/llx/scripts/grok-ro.sh`.
- Review prompts are assembled with neutral context only.
- All artifacts stay in `.parallax/runs/<run-id>/`.
- There is no `.parallax/cache`.

## Hooks Policy

Parallax v0.1 does not install hooks.

Safety comes from:

- one public `llx` skill
- deterministic wrapper scripts
- read-only Codex/Grok invocations
- per-run artifacts
- Claude as sole writer

A future version may add a `PreToolUse` safety hook to block raw unsafe `codex` or `grok` commands, but that is intentionally out of scope for v0.1.

## References

The reference briefs are duplicated into `skills/llx/references/` for runtime reliability. `_source/references/` is the canonical source; use `bash scripts/sync-references.sh` after editing it.
