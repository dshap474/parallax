![Parallax — Route planning, building, and review across models.](docs/assets/plx-readme-hero.png)

# Parallax

Multi-model coding orchestration for **Claude Code and Codex**.

Parallax is a toolbox, not a fixed script. The host agent keeps plan authorship,
review synthesis, and the final gate, while isolated headless lanes do bulk reading,
implementation, and independent criticism through one safety-pinned wrapper.

## Install

### Claude Code

```text
claude plugin marketplace add dshap474/parallax
claude plugin install plx@parallax-marketplace
```

Start a new Claude Code session, then use `/plx:dev`.

### Codex

```text
codex plugin marketplace add dshap474/parallax
codex plugin add plx@parallax-marketplace
```

Start a new Codex session, then use `$plx:dev`.

## Capabilities

| Capability | Claude Code | Codex |
| --- | --- | --- |
| Plan | `/plx:plan` | `$plx:plan` |
| Build | `/plx:build` | `$plx:build` |
| Review and fix | `/plx:review` | `$plx:review` |
| Simplify and fix | `/plx:simplify` | `$plx:simplify` |
| KISS principles | `/plx:kiss` | `$plx:kiss` |
| Orchestrator posture | `/plx:orchestrate` | `$plx:orchestrate` |
| Full pipeline | `/plx:dev` | `$plx:dev` |
| Opposite-engine passthrough | `/plx:codex` | `$plx:claude` |
| Grok passthrough | `/plx:grok` | `$plx:grok` |
| Gemini passthrough | `/plx:gemini` | `$plx:gemini` |
| Devin passthrough | `/plx:devin` | `$plx:devin` |
| Session primer | `/plx:init` | `$plx:init` |
| Blindspot work | `/plx:unknown-unknowns` | `$plx:unknown-unknowns` |

Claude is the host orchestrator in the Claude package. Codex is the host orchestrator
in the Codex package. In standalone `build`, the host delegates an accepted spec to one
fresh same-host build worker—Claude Opus 5.5 Medium or Codex `gpt-6-sol` High—which
implements it, runs three Grok 4.6 Medium review lanes itself, fixes confirmed findings
itself, and runs the full relevant verification suite; the host bootstraps and
gate-checks. The separate `dev` pipeline uses isolated Grok 4.6 writers by
default; the opposite host engine supplies its plan critics and review lanes. Direct
`review` runs three Grok 4.6 Medium lanes by default. `simplify` runs four Grok 4.6
Medium lanes over a plan or code; the host applies confirmed improvements itself. The
static `kiss` skill loads the user-authored KISS principles into the current context.
`orchestrate` loads a context-only planner posture with native subagent workers; it starts
no task or pipeline.

## Explicit model choices

Parallax defaults to `claude-opus-5-5` for Claude lanes and `gpt-6-sol` for Codex
lanes.
For example, use `$plx:claude use claude-opus-5-5 at medium for <task>` in Codex,
or `/plx:codex use gpt-6-sol at high for <task>` in Claude Code. Ask for
`gpt-6-luna` on a focused Codex task. Parallax rejects retired Opus 5 and GPT-5.6
Sol/Luna IDs, including the unpinned `opus` and `gpt-5.6` aliases. The selected CLI
must have access to the requested model. See the
[Claude model list](https://platform.claude.com/docs/en/models/overview) and
[Codex model list](https://learn.chatgpt.com/docs/models).

The one standalone Build worker intentionally receives full host access so it can write
repository Git metadata and launch its packaged review lanes. That transport is limited
to the Build worker and does not expand the accepted spec or authorize publication;
review lanes and the separate `dev` writers keep their read-only or workspace sandboxes.

`PLX::Gemini` uses Gemini CLI with `auto` model routing or an explicit model.
Install `@google/gemini-cli` and authenticate with `gemini` before use. It supports
read-only questions and sandboxed file edits; shell/test execution is disabled.
This transport currently requires macOS Seatbelt. See the
[Gemini CLI documentation](https://geminicli.com/docs/) for authentication and availability.

`PLX::Devin` is a separate single-engine passthrough. It uses SWE-2 High by default and
explicitly gives Devin full host access; questions and reviews carry a no-edit
instruction, but no sandbox enforces it. Repository-native Devin hooks, MCP servers,
rules, and skills may load. The user request and repository guidance remain the authority
boundary, and deployment, publication, credential changes, or external mutations require
exact user authorization. Explicitly retryable internal protocol failures allow up to
two fresh retries after partial work is reconciled; other failures stop immediately.

Claude's `/plx:codex` remains one-shot by default, but it may start or explicitly
resume a persistent Codex app-server thread when later continuation will materially
benefit from retained context. Pipeline lanes remain isolated and ephemeral.

## Repository layout

```text
parallax/
├── .claude-plugin/marketplace.json
├── .agents/plugins/marketplace.json
├── plugins/
│   ├── claude/plx/   # self-contained Claude Code plugin
│   └── codex/plx/    # self-contained Codex plugin
├── shared/           # canonical engine wrapper and lane rubrics
├── scripts/          # shared-copy synchronization
├── docs/
└── tests/
```

Installed plugins never reach outside their own roots. `scripts/sync-shared.sh` copies
the canonical runtime into both packages, and `--check` makes drift a test failure.

See [Architecture](docs/ARCHITECTURE.md), [Commands](docs/COMMANDS.md),
[Requirements](docs/REQUIREMENTS.md), and [Contributing](docs/CONTRIBUTING.md).

## Status

v0.5.30

## License

MIT — see [LICENSE](LICENSE).
