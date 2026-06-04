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

`skills/plx/router.md` chooses the mode. `skills/plx/modes.md` is the canonical executable workflow authority. `skills/plx/references/pipeline.md` holds shared role invariants, and `skills/plx/references/engines.md` defines engine invocation rules. `skills/plx/parallax.yaml` binds each role to an engine per mode; the orchestrator resolves it before executing.

## Modes

| Mode | Purpose | External engines |
|---|---|---|
| `quick` | small safe edits | none |
| `team` | default substantial work | Codex |
| `panel` | extra scrutiny | Codex + optional Grok |
| `ultra` | major/high-risk changes | Codex + Grok |
| `review-only` | audit/debug/critique without edits | selected read-only lanes |

## Safety Model

- Role determines repo access, not engine. Review and plan lanes are read-only for every engine; only the writer (`code`) role edits the repo, and exactly one engine fills it per mode.
- Codex/Grok review calls go through `skills/plx/scripts/codex-ro.sh` / `grok-ro.sh` (read-only).
- A non-Claude writer (when `parallax.yaml` sets `code: codex`/`grok`) goes through `skills/plx/scripts/codex-rw.sh` (scoped `workspace-write`) / `grok-rw.sh` (`acceptEdits`) — edits confined to the target repo, never full-access/bypass. Default config keeps Claude the sole writer.
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

The reference briefs live directly in `skills/plx/references/`, which is the path the installed skill reads at runtime.
