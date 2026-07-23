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

The current host authors plans, synthesizes review findings, and performs the final
gate. Headless lanes read broadly, implement, or return independent judgment. There are
no orchestration subagents: every lane is one `plx-engine` process.

The Claude package keeps Claude as host and defaults plan/review lanes to Codex. The
Codex package flips that judgment polarity: Codex remains host while Claude supplies
the default plan critics and review lanes. Both packages default implementation and
targeted fixes to Grok 4.5.

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

The three stage atoms are `plan`, `build`, and `review`; `dev` composes them and adds a
final gate. `goal-spec` prepares a self-contained autonomous goal. The host declares
task sizing before launching anything:

- trivial: one Grok writer lane and direct host verification;
- small: one writer and one correctness reviewer;
- default: two plan critics, one Grok writer, three opposite-engine review dimensions;
- large/risky: two critics, file-disjoint writers, and up to two engines per review
  dimension.

Critic and review lanes are always read-only. Write lanes use one writer per
disjoint path set. Confirmed review findings are fixed once through targeted Grok write
lanes; behavior-changing or ambiguous findings go back to the user.

## Runtime and safety

Pipeline lanes and default passthroughs use `plx-engine`. It pins:

- Codex: `gpt-5.6-sol`, isolated config, ephemeral session, read-only or workspace-write;
- Claude: Opus, project-only settings, scoped read or edit tool allowlists;
- Grok: `grok-4.5`, no planning/subagent/memory features, kernel read-only or workspace
  sandbox.

These models are defaults, not restrictions. Explicit user-requested model and effort
values pass through to the selected engine, which remains responsible for validating
them. The wrapper never uses `danger-full-access`,
`--dangerously-bypass-approvals-and-sandbox`, or `--yolo`. Runtime briefs, logs, and
outputs use temporary directories and are removed after the run; Parallax creates no
`.parallax/` state.

### Optional evaluation provenance

When `PLX_EVAL_DIR` is set to an absolute writable directory, `plx-eval` records
schema-v1 JSON evidence for routing, latency, failure, and drift analysis. Records are
local and opt-in: hashes and metadata only — never task content, prompts, diffs,
environment, credentials, or command lines. With the variable unset, behavior and
filesystem effects are unchanged unless `~/.config/parallax/env` (or the XDG equivalent)
contains a literal `PLX_EVAL_DIR=` assignment. That deterministic fallback is parsed, not
shell-sourced; an explicit process environment value takes precedence.

The four core pipelines — `plan`, `build`, `dev`, and `review` on either host — each open
one grouped run envelope (`plx-eval begin` → marker at `<tmp>/.plx-eval-run`). Their lanes
share a single run without relying on environment persistence across background shells;
`plx-engine` discovers the marker next to each flat prompt file. Other skills still get
automatic **implicit standalone-lane** records through `plx-engine` when collection is
enabled. Recording failures never change the engine result. Retention is manual pruning
for v1; use `plx-eval doctor` to check the destination. Parallax still ships no host
hooks, telemetry service, MCP, database, or target-repo `.parallax/` state.

As a narrow exception, `/plx:codex` may use `plx-codex-thread` to start or resume a
Codex app-server session. It is ephemeral by default, keeps no Parallax registry,
returns the thread ID to the user, and re-derives `inspect` or `edit` access on every
turn. Plan, build, goal-spec, dev, and review lanes never use this path.
