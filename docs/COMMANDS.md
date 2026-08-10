# Command surface

Both packages expose the same core capabilities with platform-native invocation syntax.

| Capability | Claude Code | Codex | Behavior |
| --- | --- | --- | --- |
| Plan | `/plx:plan` | `$plx:plan` | Host authors; implementation and system critics red-team; no code |
| Build | `/plx:build` | `$plx:build` | Host implements an accepted spec → Grok reviews → host fixes → full relevant verification |
| Review | `/plx:review` | `$plx:review` | Three Grok review lanes by default, synthesis, and one host-applied fix round |
| KISS | `/plx:kiss` | `$plx:kiss` | Four Grok Medium lanes simplify a plan or code; the host applies safe improvements |
| Dev | `/plx:dev` | `$plx:dev` | Plan → build → review/fix → final gate |
| Goal spec | `/plx:goal-spec` | `$plx:goal-spec` | Interview, host-authored plan, red-team, and autonomous-ready spec |
| Other host | `/plx:codex` | `$plx:claude` | Opposite-engine passthrough; default model/effort can be explicitly overridden; Claude may persist Codex context |
| Grok | `/plx:grok` | `$plx:grok` | One isolated Grok passthrough; defaults to Grok 4.5 at medium effort |
| Init | `/plx:init` | `$plx:init` | Prime the orchestrator: delegation posture + plx skill map; no repository writes |
| Agents memory | `/plx:agents-memory` | `$plx:agents-memory` | Bootstrap root `AGENTS.md`, `CLAUDE.md`, and `.project/` policy |
| Unknowns | `/plx:unknown-unknowns` | `$plx:unknown-unknowns` | Host-only blindspot and comprehension work |

Codex skills are explicit-only (`allow_implicit_invocation: false`) so an expensive
pipeline never starts merely because a prompt resembles its description.

`/plx:codex` uses the isolated one-shot engine path unless explicit continuation or
likely multi-turn repository rediscovery justifies a persistent app-server thread. A
resume requires a known thread ID, and every turn derives read or write access anew.
All single-engine passthroughs accept explicit model and effort requests in natural
language (for example, `$plx:claude ask fable medium for <task>`). The host converts
those settings into engine launch flags; omitted settings retain their defaults.

Configured pipelines read their package-local `config/parallax.yaml`. Config is the
floor shape, not a limit: the host may scale lanes down or up and must declare the
chosen shape before launching. Standalone Build is host-implemented and has no writer
binding. KISS always runs reuse, simplification, efficiency, and altitude once each on
Grok Medium. A current-message instruction may replace the engine for the whole round.
Skills never commit or publish; target-repository instructions govern Git.

## Runtime tools (package-local `bin/`)

| Tool | Role |
| --- | --- |
| `plx-engine` | Headless engine wrapper (safety pinned) |
| `plx-preflight` | Real probe of required/optional engines |
| `plx-config` | Print `config/parallax.yaml` |
| `plx-skill` | Print a pipeline skill or reference |
| `plx-link-claude` | Mirror `AGENTS.md` → `CLAUDE.md` symlinks |
| `plx-eval` | Optional local SQLite trace capture (`PLX_TRACE_DB`) |

`plx-eval` commands: `lane`, `finish`, `doctor`. See `plx-eval --help` and
[Architecture](ARCHITECTURE.md) for schema, privacy limits, grouped runs, and standalone
fallback. If exporting `PLX_TRACE_DB` globally is undesirable, put the literal assignment
in `~/.config/parallax/env`; it may symlink to a git-ignored checkout `.env`.
