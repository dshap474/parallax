# Architecture

Parallax ships two host-native plugins over one runtime contract.

```text
Claude Code host                         Codex host
/plx:* skills                            $plx:<skill> skills
      │                                        │
      └────────── package-local plx-engine ────┘
                    │
             Codex · Claude · Grok
```

## Host responsibilities

The current host authors plans, orchestrates standalone Build, synthesizes review
findings, applies confirmed fixes, and performs the final gate. Headless lanes read
broadly, implement in standalone Build or the separate `dev` pipeline, or return
independent judgment. Every lane is one isolated `plx-engine` process.

The Claude package keeps Claude as host and defaults plan critics and composed `dev`
review lanes to Codex. The Codex package flips that judgment polarity: Codex remains
host while Claude supplies those lanes. Direct `review` instead runs all three core
lanes on Grok by default. Standalone Build delegates the whole build to one fresh
same-host worker (Codex `gpt-5.6-sol` High or Claude Opus Medium) that implements, runs
its three Grok 4.6 Medium review lanes, and fixes confirmed findings itself; the host
bootstraps and gate-checks. The separate `dev` pipeline prefers Grok
4.6 for implementation, deterministically falls back to Codex only when Grok fails
preflight, and keeps targeted review fixes with the host.

## Package boundaries

Each package contains its own manifest, skills, config, `bin/`, `prompts/`, and license.
This is required because both plugin systems copy installed plugins into caches. Runtime
paths therefore never traverse to repository-level shared files.

`shared/bin/` and `shared/prompts/` are canonical source files.
`scripts/sync-shared.sh` copies them into both packages, while
`scripts/sync-shared.sh --check` verifies byte-for-byte agreement. Skills and engine
configs remain platform-specific because invocation syntax, host tools, and review
polarity differ.

The Claude package additionally vendors `codex-app-client` and a thin
`plx-codex-thread` wrapper. They support optional persistence only for `/plx:codex`;
the Codex package does not ship them. Shared synchronization explicitly preserves that
one Claude-only wrapper.

## Pipeline

`plan`, `build`, `review`, and `dev` are separate workflows. `dev` is self-contained; it
does not invoke the standalone Build or Review skills. Standalone Build requires an
accepted spec and delegates it to one fresh same-host build worker that implements, runs
three Grok review lanes, fixes confirmed findings, and finishes with the complete
relevant verification suite; the host bootstraps and gate-checks.
`simplify` simplifies a plan or code. `kiss` loads the user-authored KISS principles into
the host context. `goal-spec` prepares a self-contained autonomous goal.

Inside `dev`, the host declares task sizing before launching anything:

- trivial: one configured writer lane and direct host verification;
- small: one writer and one correctness reviewer;
- default: two plan critics, one configured writer, three opposite-engine core review
  dimensions;
- large/risky: two critics, file-disjoint writers, the risk-triggered security dimension,
  and up to two engines per review dimension.

Critic and review lanes are always read-only. `dev` write lanes use one writer per
disjoint path set. Standalone Build uses exactly one fresh same-host build worker and
never falls through to another writer or parallel host implementation. In `dev` and
`review`, confirmed review findings are fixed once by the host; in standalone Build the
worker fixes them once itself. Behavior-changing or ambiguous findings go back to the
user.

Simplify runs four independent Grok 4.6 Medium dimensions: reuse, simplification,
efficiency, and altitude. The host validates their findings and applies the smallest safe changes.
It complements rather than replaces correctness review.

## Runtime and safety

Pipeline lanes and default passthroughs use `plx-engine`. It pins:

- Codex: `gpt-5.6-sol`, user config ignored, approval policy `never`, ephemeral session,
  and an explicit filesystem sandbox;
- Claude: Opus, safe mode, no session persistence, strict MCP/network isolation,
  read-only tools or repo-confined sandboxed Bash;
- Grok: `grok-4.6` at medium reasoning, unattended tool approval, no
  planning/subagent/memory features, and an explicit read-only or workspace sandbox.

These models are defaults, not restrictions. Explicit user-requested model and effort
values pass through to the selected engine except that `grok-4.6` is always normalized
to medium reasoning. The selected engine remains responsible for validating other values.
Normal lanes use read-only or workspace-constrained execution. The one standalone Build
writer intentionally uses full host access: Codex `danger-full-access`, or Claude with
its sandbox disabled and `--dangerously-skip-permissions`. The wrapper accepts that mode
only for an `rw` `worker`/`build-worker` lane. It is a transport requirement for Git
metadata and packaged review launches, not permission to expand the accepted spec,
repository scope, or publication authority. Review lanes remain read-only. Codex never
uses `--dangerously-bypass-approvals-and-sandbox` or `--yolo`.

Claude safe mode disables automatic project customization, so the wrapper supplies a
deterministic list of physical source-tree `AGENTS.md`, `CLAUDE.md`, `CLAUDE.local.md`,
and `.claude/rules/*.md` files, including ignored and untracked guidance while excluding
common dependency/cache trees. Root guidance is repo-wide; nested guidance is
path-scoped. Runtime briefs, logs, and outputs use
`plx-`-prefixed temporary directories and the confined `plx-clean-temp` helper;
Parallax creates no `.parallax/` state.

### Optional trace capture

When `PLX_TRACE_DB` names an absolute SQLite path, `plx-eval` stores schema-v1 skill runs
and engine lanes for later routing and quality analysis. Records are local and opt-in,
and include complete task, prompt, trace, and final-output text; treat the database as
sensitive. With the variable unset, capture stays disabled unless
`~/.config/parallax/env` (or the XDG equivalent) contains a literal `PLX_TRACE_DB=`
assignment. That fallback is parsed, never shell-sourced, and an explicit process value
takes precedence.

`plx-engine` records each completed lane from its exit trap without changing the engine
exit code. Prompt files directly under a `plx-<skill>.<suffix>` temp directory share that
directory basename as their run ID. A direct engine call from any other directory creates
and closes a standalone run. Every operational skill calls `plx-eval finish` once;
host-only operational skills therefore produce a useful zero-lane run. The context-only
KISS principles skill performs no runtime work and creates no trace. An interruption
before `finish` leaves a grouped run incomplete. Connections enable foreign keys, WAL, and a
five-second busy timeout. Retention and schema migration remain manual for v1;
`plx-eval doctor` checks integrity and counts. Parallax ships no host hooks, telemetry daemon, MCP, or target-repo
`.parallax/` state. Persistent `plx-codex-thread` internals are not yet lane-captured, but
their enclosing passthrough skill run is recorded.

As a narrow exception, `/plx:codex` may use `plx-codex-thread` to start or resume a
Codex app-server session. It is ephemeral by default, keeps no Parallax registry,
returns the thread ID to the user, and re-derives `inspect` or `edit` access on every
turn. Plan, build, goal-spec, dev, review, and Simplify lanes never use this path.
