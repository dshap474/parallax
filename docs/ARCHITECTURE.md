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

GPT-5.5 and Sonnet are rejected. The wrapper never uses `danger-full-access`,
`--dangerously-bypass-approvals-and-sandbox`, or `--yolo`. Runtime briefs, logs, and
outputs use temporary directories and are removed after the run; Parallax creates no
`.parallax/` state.

As a narrow exception, `/plx:codex` may use `plx-codex-thread` to start or resume a
Codex app-server session. It is ephemeral by default, keeps no Parallax registry,
returns the thread ID to the user, and re-derives `inspect` or `edit` access on every
turn. Plan, build, goal-spec, dev, and review lanes never use this path.
