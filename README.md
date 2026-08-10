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
| Keep it simple | `/plx:kiss` | `$plx:kiss` |
| Full pipeline | `/plx:dev` | `$plx:dev` |
| Autonomous goal spec | `/plx:goal-spec` | `$plx:goal-spec` |
| Opposite-engine passthrough | `/plx:codex` | `$plx:claude` |
| Grok passthrough | `/plx:grok` | `$plx:grok` |
| Session primer | `/plx:init` | `$plx:init` |
| Repository setup | `/plx:agents-memory` | `$plx:agents-memory` |
| Blindspot work | `/plx:unknown-unknowns` | `$plx:unknown-unknowns` |

Claude is the host orchestrator in the Claude package. Codex is the host orchestrator
in the Codex package. In standalone `build`, the host implements an accepted spec,
three Grok lanes review it, the host fixes confirmed findings, and the full relevant
verification suite runs. The separate `dev` pipeline uses isolated Grok 4.5 writers by
default; the opposite host engine supplies its plan critics and review lanes. Direct
`review` runs three Grok lanes by default. `kiss` runs four Grok Medium lanes over a
plan or code; the host applies confirmed improvements itself.

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

v0.5.12

## License

MIT — see [LICENSE](LICENSE).
