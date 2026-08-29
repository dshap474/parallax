# Command surface

Both packages expose the same core capabilities with platform-native invocation syntax.

| Capability | Claude Code | Codex | Behavior |
| --- | --- | --- | --- |
| Plan | `/plx:plan` | `$plx:plan` | Host authors; implementation and system critics red-team; no code |
| Build | `/plx:build` | `$plx:build` | One fresh same-host build worker implements an accepted spec → runs Grok 4.6 Medium reviews → fixes → full relevant verification; host bootstraps and gate-checks |
| Review | `/plx:review` | `$plx:review` | Three Grok 4.6 Medium review lanes by default, synthesis, and one host-applied fix round |
| Simplify | `/plx:simplify` | `$plx:simplify` | Four Grok 4.6 Medium lanes simplify a plan or code; the host applies safe improvements |
| KISS | `/plx:kiss` | `$plx:kiss` | Print the user-authored KISS principles exactly as written |
| Dev | `/plx:dev` | `$plx:dev` | Plan → build → review/fix → final gate |
| Goal spec | `/plx:goal-spec` | `$plx:goal-spec` | Interview, host-authored plan, red-team, and autonomous-ready spec |
| Other host | `/plx:codex` | `$plx:claude` | Opposite-engine passthrough; default model/effort can be explicitly overridden; Claude may persist Codex context |
| Grok | `/plx:grok` | `$plx:grok` | One isolated Grok passthrough; Grok 4.6 always uses medium effort |
| Init | `/plx:init` | `$plx:init` | Prime the orchestrator: delegation posture + plx skill map; no repository writes |
| Agents memory | `/plx:agents-memory` | `$plx:agents-memory` | Bootstrap root `AGENTS.md`, `CLAUDE.md`, and `.project/` policy |
| Unknowns | `/plx:unknown-unknowns` | `$plx:unknown-unknowns` | Host-only blindspot and comprehension work |

All skills are explicit-only so an expensive pipeline never starts merely because a
prompt resembles its description. Codex uses `allow_implicit_invocation: false`; Claude
uses `disable-model-invocation: true` with `user-invocable: true`.

`/plx:codex` uses the isolated one-shot engine path unless explicit continuation or
likely multi-turn repository rediscovery justifies a persistent app-server thread. A
resume requires a known thread ID, and every turn derives read or write access anew.
All single-engine passthroughs accept explicit model and effort requests in natural
language (for example, `$plx:claude ask fable medium for <task>`). The host converts
those settings into engine launch flags; omitted settings retain their defaults. Grok
4.6 is the one model-specific exception: its reasoning is always normalized to medium.

Configured pipelines read their package-local `config/parallax.yaml`. Config is the
floor shape, not a limit: the host may scale lanes down or up and must declare the
chosen shape before launching. Standalone Build always uses one fresh same-host build
worker that owns implementation, Grok review, fixes, and verification: Claude Opus Medium
or Codex `gpt-5.6-sol` High, with no fallback or second writer. Simplify
always runs reuse, simplification, efficiency, and altitude once each on Grok 4.6 Medium. A
current-message instruction may replace the engine for the whole round.
KISS is a static principles skill and launches no engine lanes.
Standalone Build may create local commits when its accepted spec or the target
repository's instructions explicitly require or authorize them. It stages only
Build-owned work and reports every commit. Other skills retain their documented Git
policies. No skill pushes, opens a pull request, merges, tags, releases, deploys, or
publishes externally without separate authority; target-local artifacts explicitly
required by an accepted spec are allowed.

The standalone Build worker is the only full-access engine lane. Codex uses
`danger-full-access`; Claude disables its sandbox and uses its explicit permission
bypass. Review lanes and `dev` writers keep their configured read-only or workspace
sandbox, and full access never expands the accepted task or publication authority.

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
