# Requirements & Setup

Parallax orchestrates external model CLIs that you install and authenticate. It does not bundle, host, or proxy any model. All engine execution goes through `bin/plx-engine` (`--engine codex|grok|claude --mode ro|rw`); the old per-engine wrappers (`plx-codex-ro`/`-rw`, `plx-grok-ro`/`-rw`) remain as back-compat shims.

## Engines

| Engine | Install | Used by default | Required? |
|---|---|---|---|
| Codex | `codex` CLI + auth | plan-critic, planner, and review lanes in `dev`/`goal-spec`/`review`; `/plx:codex` | required for the shipped pipeline configs |
| Grok | `grok` CLI + auth | `/plx:grok`; optional second-perspective lanes | optional |
| Claude | `claude` CLI (already present — it runs your session) | the writer lane (`code: claude`); any lane you bind it to | present by definition |

The shipped configs bind the critic/planner/reviewer lanes to Codex, so Codex is required to run the pipelines as configured. Bindings are defaults, not limits — see `prompts/engines.md`. Validate whatever a run needs with `plx-preflight --repo <repo> --require-<engine>` (each probe spends a tiny model call).

## Codex

Install and authenticate the Codex CLI (`codex` on `PATH`).

`plx-engine --engine codex` pins:

- `--ignore-user-config` and `--ephemeral` (no session state, no user-config bleed)
- sandbox `read-only` (`--mode ro`) or `workspace-write` (`--mode rw`)
- `--effort low|medium|high|xhigh` (default `high`) and `--model` (default `gpt-5.5` — `gpt-5.3-codex` is unavailable on some ChatGPT-account auth)

Codex writes only in `--mode rw` (the `code: codex` binding or `/plx:codex`). No mode uses `danger-full-access` or `--yolo`.

## Grok

Install and authenticate the Grok CLI (`grok login`, or set `XAI_API_KEY`). Verified with grok 0.2.32 (`grok-composer-2.5-fast`); final-message extraction and headless permission behavior re-verified with 0.2.39.

`plx-engine --engine grok` pins a kernel-enforced sandbox (Seatbelt on macOS, Landlock on Linux):

- `--mode ro` → `--sandbox read-only`: grok may read but cannot write the repo (OS-denied).
- `--mode rw` → `--sandbox workspace`: edits confined to the repo; writes outside are kernel-denied and logged to `~/.grok/sandbox-events.jsonl`.

Both modes pass `--permission-mode bypassPermissions`, because grok's CLI only *enforces* that mode (and `default`) — `acceptEdits`/`plan` are accepted but unenforced and would cancel the turn in headless. Confinement comes from the sandbox, not the permission mode.

The wrapper emits only the model's final message (recovered from grok's session store, since the JSON envelope aggregates narration and subagent streams) and deletes the run's `~/.grok/sessions` entry on success (kept on failure for debugging — grok has no `--ephemeral`). Grok takes no `--effort`/`--model` flags: `grok-composer-2.5-fast` rejects the `reasoningEffort` parameter (API 400).

When invoking grok from Claude Code, disable the Claude Bash sandbox for that call only (grok needs network/keychain access the sandbox blocks). The wrapper decides success from grok's `stopReason` + output: **0** = ok, **3** = not signed in (run `grok login`), **1** = real failure. grok prints non-fatal `AuthorizationRequired` worker lines to stderr even on success — judge by the exit code.

## Claude

The `claude` CLI is already installed and authenticated — it is the session you are in. `plx-engine --engine claude` runs it headless as a lane engine:

- non-bare `claude -p` with `--setting-sources project` (`--bare` fails on subscription auth)
- `--mode ro` → `--permission-mode dontAsk` + `Read,Grep,Glob` allowlist
- `--mode rw` → `--permission-mode acceptEdits` + `Read,Grep,Glob,Edit,Write,Bash` allowlist
- `--effort` (default `high`) and `--model` (default `opus`); rubrics injected via `--append-system-prompt-file`

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
