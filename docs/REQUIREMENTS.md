# Requirements & Setup

Parallax orchestrates external model CLIs that you install and authenticate. It does not bundle, host, or proxy any model. All engine execution goes through `bin/plx-engine` (`--engine codex|grok|claude --mode ro|rw`).

## Engines

| Engine | Install | Used by default | Required? |
|---|---|---|---|
| Codex | `codex` CLI + auth | default writer, implementation/system plan critics, planner, and review lanes; `/plx:codex` | required for the shipped pipeline configs |
| Grok | `grok` CLI + auth | approved writer alternative; optional fix/second-perspective lanes; `/plx:grok` | optional |
| Claude | `claude` CLI (already present — it runs your session) | optional Opus planning/review lanes | present by definition |

The shipped configs bind the critic/planner/reviewer lanes to Codex, so Codex is required to run the pipelines as configured. Bindings are defaults, not limits — see `prompts/engines.md`. Validate whatever a run needs with `plx-preflight --repo <repo> --require-<engine>` (each probe spends a tiny model call).

## Codex

Install and authenticate the Codex CLI (`codex` on `PATH`).

`plx-engine --engine codex` pins:

- `--ignore-user-config` and `--ephemeral` (no session state, no user-config bleed)
- sandbox `read-only` (`--mode ro`) or `workspace-write` (`--mode rw`)
- `--effort low|medium|high|xhigh` (default `medium`) and `--model` (default `gpt-5.6-sol`)

Codex writes only in `--mode rw` (the `code: codex` binding or `/plx:codex`). GPT-5.5
and Sonnet are forbidden across every engine and rejected as usage errors. No mode uses
`danger-full-access` or `--yolo`.

## Grok

Install Grok Build 0.2.89 or newer and authenticate it (`grok login`, or set
`XAI_API_KEY`). Version 0.2.89 introduced the current effort flags; this release is
verified against grok 0.2.101 with `grok-4.5` available.

`plx-engine --engine grok` fixes the model to `grok-4.5`. Effort defaults to `medium`;
callers may explicitly select `low` or `high`. Any other model or effort, including
`xhigh`, is a usage error. The wrapper passes current headless automation flags:
`--no-auto-update`, `--no-plan`, `--no-subagents`, `--no-memory`, `--no-alt-screen`, and
`--output-format json`.

These settings follow the current xAI [Grok 4.5 model documentation](https://docs.x.ai/developers/grok-4-5),
[CLI reference](https://docs.x.ai/build/cli/reference),
[headless scripting guide](https://docs.x.ai/build/cli/headless-scripting), and
[enterprise sandbox documentation](https://docs.x.ai/build/enterprise).

`plx-engine --engine grok` pins a kernel-enforced sandbox (Seatbelt on macOS, Landlock on Linux):

- `--mode ro` → `--sandbox read-only`: grok may read but cannot write the repo (OS-denied).
- `--mode rw` → `--sandbox workspace`: edits confined to the repo; writes outside are kernel-denied and logged to `~/.grok/sandbox-events.jsonl`.

Both modes pass `--permission-mode bypassPermissions` so arbitrary repo-specific toolchains
can complete headlessly. Grok Build defines this as an always-approve permission posture;
confinement comes from the kernel sandbox, not the permission mode. Parallax never uses the
`--always-approve` or `--yolo` spellings.

The wrapper emits only the model's final message. It retains the session-store fallback for
older Grok builds whose JSON envelope aggregated narration and subagent streams, even though
current Parallax runs disable subagents. It deletes the run's `~/.grok/sessions` entry on
success and keeps it on failure for debugging because Grok has no `--ephemeral` flag.

When invoking grok from Claude Code, disable the Claude Bash sandbox for that call only (grok needs network/keychain access the sandbox blocks). The wrapper decides success from grok's `stopReason` + output: **0** = ok, **3** = not signed in (run `grok login`), **1** = real failure. grok prints non-fatal `AuthorizationRequired` worker lines to stderr even on success — judge by the exit code.

## Claude

The `claude` CLI is already installed and authenticated — it is the session you are in. `plx-engine --engine claude` runs it headless as a lane engine:

- non-bare `claude -p` with `--setting-sources project` (`--bare` fails on subscription auth)
- `--mode ro` → `--permission-mode dontAsk` + `Read,Grep,Glob` allowlist
- `--mode rw` → `--permission-mode acceptEdits` + `Read,Grep,Glob,Edit,Write,Bash` allowlist
- `--effort` (default `high`) and `--model` (default `opus`); rubrics injected via `--append-system-prompt-file`

Sonnet is not an allowed model. Claude remains available for optional Opus planning and
review work; it is not a shipped implementation default.

Blocked tool calls abort the run rather than hang. No bypass flags, ever.

## Lane runtime

Engine turns can run 10–40+ minutes. Pipelines launch every lane as background Bash with `--out <f> --log <f>`; foreground calls cap at 10 minutes. Headless `claude -p` itself caps background-subagent waits at 10 minutes (since v2.1.182) — tunable via `CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS` (0 = unlimited), which the smoke suite sets.

## Verification toolchain

The orchestrator and the writer lane run the target repo's own checks directly, such as `.venv/bin/ruff check .`, `.venv/bin/pytest -q`, `npm test`, `cargo test`, or `go test`.

Never use `uv run` inside a sandbox; Homebrew `uv` can panic there.

## Runtime state

Parallax does not use repo-local runtime state. It does not create:

```text
.parallax/
.parallax/cache/
.parallax/runs/
```

Preflight and `plx-engine` may use `mktemp -d` internally for CLI prompt/output/log files, but those directories are removed before the command returns. Pipeline stage artifacts live in a shell temp directory the orchestrator creates and cleans up. Final results are returned in chat.
