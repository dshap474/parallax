# Architecture

Parallax is a router-first, role-based coding workflow for Claude Code.

The public surface is one skill:

```text
/parallax:plx <task>
```

Internally, `plx` selects a mode:

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

`skills/plx/router.md` chooses the mode. `skills/plx/modes.md` is the canonical executable workflow authority. `skills/plx/references/pipeline.md` holds shared role invariants, and `skills/plx/references/engines.md` defines engine invocation rules.

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
- Codex calls go through `skills/plx/scripts/codex-ro.sh`.
- Grok calls go through `skills/plx/scripts/grok-ro.sh`.
- Review prompts are assembled with neutral context only.
- Parallax does not create `.parallax/`, `.parallax/cache`, or `.parallax/runs`.
- Runtime prompts, logs, and external model outputs are chat context or temp files that are cleaned up before commands return.

## Hooks Policy

Parallax v0.1 does not install hooks.

Safety comes from:

- one public `plx` skill
- deterministic wrapper scripts
- read-only Codex/Grok invocations
- no repo-local runtime state
- Claude as sole writer

A future version may add a `PreToolUse` safety hook to block raw unsafe `codex` or `grok` commands, but that is intentionally out of scope for v0.1.

## References

The reference briefs live directly in `skills/plx/references/`, which is the path the installed skill reads at runtime.
