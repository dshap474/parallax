# Command surface

Both packages expose the same core capabilities with platform-native invocation syntax.

| Capability | Claude Code | Codex | Behavior |
| --- | --- | --- | --- |
| Plan | `/plx:plan` | `$plx:plan` | Host authors; one opposite-host reviewer checks the plan; no code |
| Build | `/plx:build` | `$plx:build` | One GPT-6 Sol High worker in Codex or Opus 5.5 Medium worker in Claude Code implements and verifies an accepted spec |
| Review | `/plx:review` | `$plx:review` | Three Grok 4.5 Medium review lanes by default, synthesis, and one host-applied fix round |
| Simplify | `/plx:simplify` | `$plx:simplify` | Four Grok 4.6 Medium lanes simplify a plan or code; the host applies safe improvements |
| KISS | `/plx:kiss` | `$plx:kiss` | Load the user-authored KISS principles into the current context |
| Orchestrate | `/plx:orchestrate` | `$plx:orchestrate` | Set a planner and worker-delegation posture without starting work |
| Dev | `/plx:dev` | `$plx:dev` | Plan → build → review/fix → final gate |
| Other host | `/plx:codex` | `$plx:claude` | Opposite-engine passthrough; default model/effort can be explicitly overridden; Claude may persist Codex context |
| Grok | `/plx:grok` | `$plx:grok` | One isolated Grok passthrough; Grok 4.6 always uses medium effort |
| Devin | `/plx:devin` | `$plx:devin` | One full-access Devin passthrough; SWE-2 High by default; no generic effort flag |
| Init | `/plx:init` | `$plx:init` | Load the Parallax skill map and research defaults into context |
| Unknowns | `/plx:unknown-unknowns` | `$plx:unknown-unknowns` | Host-only blindspot and comprehension work |

All skills are explicit-only so an expensive pipeline never starts merely because a
prompt resembles its description. Codex uses `allow_implicit_invocation: false`; Claude
uses `disable-model-invocation: true` with `user-invocable: true`.

`/plx:codex` uses the isolated one-shot engine path unless explicit continuation or
likely multi-turn repository rediscovery justifies a persistent app-server thread. A
resume requires a known thread ID, and every turn derives read or write access anew.
Codex, Claude, and Grok passthroughs accept explicit model and effort requests in natural
language (for example, `$plx:claude ask fable medium for <task>`). The host converts
those settings into engine launch flags; omitted settings retain their defaults. Grok
4.6 is always normalized to medium. Devin accepts an exact model ID instead: medium,
high, and max map to `swe-2-medium`, `swe-2-high`, and `swe-2-max`; a separate effort
value is rejected.

Plan, Build, and Review own their model defaults in their skills. Dev calls them
sequentially. Simplify alone reads engine bindings from `config/parallax.yaml`.
Review runs its core lanes in parallel and accepts an explicit whole-round engine
override.

Standalone Build always uses one fresh same-host worker for implementation and
verification: Claude Opus 5.5 Medium or Codex `gpt-6-sol` High, with no fallback or
second writer. Simplify
always runs reuse, simplification, efficiency, and altitude once each on Grok 4.6 Medium. A
current-message instruction may replace the engine for the whole round.
KISS is a context-only principles skill and launches no engine lanes.
Orchestrate is also context-only. When invoked, it guides the host to plan and use
native subagents for execution; it does not launch workers itself or change pipeline routing.
Standalone Build may create local commits when its accepted spec or the target
repository's instructions explicitly require or authorize them. It stages only
Build-owned work and reports every commit. Other skills retain their documented Git
policies. No skill pushes, opens a pull request, merges, tags, releases, deploys, or
publishes externally without separate authority; target-local artifacts explicitly
required by an accepted spec are allowed.

The standalone Build worker uses full access. Codex uses
`danger-full-access`; Claude disables its sandbox and uses its explicit permission
bypass. Plan and Review lanes stay read-only; full access never expands the accepted
task or publication authority.
The standalone Devin passthrough is also explicitly full access, using Devin's dangerous
permission mode without its OS sandbox. It is not a Build, review, or fallback lane and
does not change any pipeline routing.

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
