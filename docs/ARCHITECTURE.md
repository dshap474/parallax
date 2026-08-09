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

The current host authors plans, directly implements accepted specs in standalone Build,
synthesizes review findings, applies confirmed fixes, and performs the final gate.
Headless lanes read broadly, implement only inside the separate `dev` pipeline, or
return independent judgment. There are no orchestration subagents: every lane is one
`plx-engine` process.

The Claude package keeps Claude as host and defaults plan critics and composed `dev`
review lanes to Codex. The Codex package flips that judgment polarity: Codex remains
host while Claude supplies those lanes. Direct `review` instead runs all three core
lanes on Grok by default. Standalone Build also uses Grok for its three review lanes,
while the host owns implementation and fixes. The separate `dev` pipeline prefers Grok
4.5 for implementation, deterministically falls back to Codex only when Grok fails
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
accepted spec, has the host implement it, runs three Grok review lanes, has the host fix
confirmed findings, and finishes with the complete relevant verification suite.
`simplify` is a standalone post-implementation quality pipeline, and `goal-spec`
prepares a self-contained autonomous goal.

Inside `dev`, the host declares task sizing before launching anything:

- trivial: one configured writer lane and direct host verification;
- small: one writer and one correctness reviewer;
- default: two plan critics, one configured writer, three opposite-engine core review
  dimensions;
- large/risky: two critics, file-disjoint writers, the risk-triggered security dimension,
  and up to two engines per review dimension.

Critic and review lanes are always read-only. `dev` write lanes use one writer per
disjoint path set. Standalone Build has no write lane: the host is its only writer.
Confirmed review findings are fixed once by the host; behavior-changing or ambiguous
findings go back to the user.

Simplify is deliberately fixed at four independent read-only dimensions: reuse,
simplification, efficiency, and altitude. It defaults to the opposite host engine, while
an explicit whole-round engine request replaces all four bindings. The host deduplicates,
validates, and applies only small behavior-preserving fixes. Simplify does not run inside
`dev` and does not replace correctness review.

## Runtime and safety

Pipeline lanes and default passthroughs use `plx-engine`. It pins:

- Codex: `gpt-5.6-sol`, isolated config, ephemeral session, read-only or workspace-write;
- Claude: Opus, safe mode, no session persistence, strict MCP/network isolation,
  read-only tools or repo-confined sandboxed Bash;
- Grok: `grok-4.5`, no planning/subagent/memory features, kernel read-only or workspace
  sandbox.

These models are defaults, not restrictions. Explicit user-requested model and effort
values pass through to the selected engine, which remains responsible for validating
them. The wrapper never uses `danger-full-access`,
`--dangerously-bypass-approvals-and-sandbox`, or `--yolo`. Runtime briefs, logs, and
outputs use `plx-`-prefixed temporary directories and the confined `plx-clean-temp`
helper; Parallax creates no `.parallax/` state.

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
and closes a standalone run. Every user-facing skill calls `plx-eval finish` once; host-only
skills therefore produce a useful zero-lane run. An interruption before `finish` leaves a
grouped run incomplete. Connections enable foreign keys, WAL, and a five-second busy
timeout. Retention and schema migration remain manual for v1; `plx-eval doctor` checks
integrity and counts. Parallax ships no host hooks, telemetry daemon, MCP, or target-repo
`.parallax/` state. Persistent `plx-codex-thread` internals are not yet lane-captured, but
their enclosing passthrough skill run is recorded.

As a narrow exception, `/plx:codex` may use `plx-codex-thread` to start or resume a
Codex app-server session. It is ephemeral by default, keeps no Parallax registry,
returns the thread ID to the user, and re-derives `inspect` or `edit` access on every
turn. Plan, build, goal-spec, dev, review, and simplify lanes never use this path.
