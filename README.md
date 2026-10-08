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
| Fanout and synthesize | `/plx:fanout-and-synthesize` | `$plx:fanout-and-synthesize` |
| Adversarial verification | `/plx:adversarial-verification` | `$plx:adversarial-verification` |
| Generate and filter | `/plx:generate-and-filter` | `$plx:generate-and-filter` |

Model defaults, override syntax, and per-skill behavior are in
[Commands](docs/COMMANDS.md). For example, use `$plx:claude use claude-opus-5-5 at
medium for <task>` in Codex or `/plx:codex use gpt-6.1-sol at high for <task>` in
Claude Code. See the [Claude model list](https://platform.claude.com/docs/en/models/overview),
[Codex model list](https://learn.chatgpt.com/docs/models), and
[Gemini CLI documentation](https://geminicli.com/docs/).

The standalone Build worker, the opposite-host passthroughs, and the Devin passthrough
run with full host access; every other lane is read-only or workspace-confined. See
[Architecture](docs/ARCHITECTURE.md#runtime-and-safety).

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

v0.5.37

## License

MIT — see [LICENSE](LICENSE).
