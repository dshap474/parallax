# Architecture

Parallax ships two host-native plugins over one runtime contract.

```text
Claude Code host                         Codex host
/plx:* skills                            $plx:<skill> skills
      │                                        │
      └────────── package-local plx-engine ────┘
                    │
        Codex · Claude · Grok · Gemini · Devin
```

## Host responsibilities

The current host authors plans, delegates Build, synthesizes Review and Simplify
findings, applies confirmed fixes, and performs the final gate. Each headless lane is
one isolated `plx-engine` process. Model defaults per skill are listed in
[Commands](COMMANDS.md).

## Package boundaries

Each package contains its own manifest, skills, `bin/`, `prompts/`, and license.
Both plugin systems copy installed plugins into caches, so runtime paths never
traverse to repository-level shared files.

`shared/bin/` and `shared/prompts/` are canonical. `scripts/sync-shared.sh` copies them
into both packages and `--check` verifies byte-for-byte agreement. Skills stay
platform-specific because invocation syntax, host tools, and review polarity differ.

## Pipeline

`plan`, `build`, and `review` are separate workflows; `dev` runs them in sequence.
Plan and Review lanes are read-only. Build requires an accepted spec and delegates it to
one fresh same-host worker with no fallback writer. Review verifies lane findings and
the host fixes confirmed ones; behavior-changing or ambiguous findings go back to the
user. Simplify runs four read-only dimensions (reuse, simplification, efficiency,
altitude) and the host applies the smallest safe changes; it complements correctness
review. `kiss`, `orchestrate`, and `init` load context only and launch no lanes.

## Runtime and safety

`plx-engine` pins transport settings per engine; callers choose only engine, mode,
rubric, model, and effort.

- Codex: user config ignored, approval policy `never`, ephemeral session, explicit
  read-only or workspace-write sandbox. Never the approvals-and-sandbox bypass or `--yolo`.
- Claude: safe mode, no session persistence, strict MCP/network isolation, read-only
  tools or repo-confined sandboxed Bash. Safe mode disables guidance discovery, so the
  wrapper lists physical `AGENTS.md`, `CLAUDE.md`, `CLAUDE.local.md`, and
  `.claude/rules/*.md` files in the prompt, including ignored and untracked ones.
- Grok: `grok-4.6` always at medium, unattended tool approval, no planning, subagent,
  or memory features, and an explicit read-only or workspace kernel sandbox. A sandbox
  startup failure prints `PLX_GROK_SANDBOX_UNAVAILABLE` and never authorizes
  host-session substitution.
- Gemini: `auto` routing by default, sandbox required (macOS Seatbelt), read tools in
  `ro` and file-edit tools in `rw`; shell, extensions, MCP, and hooks disabled.
- Devin: one-shot print mode, generated config with imports, updates, and subagents
  disabled, workspace-trust prompt skipped, dangerous permission mode, no OS sandbox. Repository-native Devin hooks,
  MCP servers, rules, and skills may still load. The wrapper lists repository guidance,
  requires a terminal ATIF response and exit 0, and stops its process group on
  interruption.

Full host access exists on exactly three paths: the single standalone Build worker
(`rw` `build-worker` lane, so it can write Git metadata and launch review lanes), the
explicit rubric-free opposite-host passthroughs (`/plx:codex`, `$plx:claude`), and the
Devin passthrough. Full access is a transport setting. It never expands the accepted
spec or user request, and never authorizes publication or external mutations.
Questions and reviews sent to full-access engines carry a no-edit instruction that no
sandbox enforces.

Standalone Build may create local commits that its accepted spec or the target
repository's instructions require, staging only Build-owned work. No skill pushes,
opens a pull request, merges, tags, releases, deploys, or publishes without separate
authority. Runtime briefs, logs, and outputs live in `plx-`-prefixed temp directories
removed by the confined `plx-clean-temp` helper. Parallax adds no hooks, telemetry,
MCP, or target-repo `.parallax/` state.
