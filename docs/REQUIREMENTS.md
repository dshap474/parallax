# Requirements & Setup

Parallax orchestrates external model CLIs that you install and authenticate. It does not bundle, host, or proxy any model.

## Engines

| Engine | Install | Used by | Required? |
|---|---|---|---|
| Codex | `codex` CLI + auth | `dev`/`goal-spec`/`review` plan and review lanes; `/plx:codex` | required for the default pipelines |
| Grok | `grok` CLI + auth | `/plx:grok` passthrough; opt-in `code: grok` writer; parked for future ultra tiers | optional |

The default `dev`, `goal-spec`, and `review` pipelines bind their planner and reviewer lanes to Codex, so Codex is required to run them as shipped. Grok is only needed for the `/plx:grok` passthrough and the opt-in `code: grok` writer today. The orchestrator (Claude) is always present — it is the session you are in.

## Codex

Install and authenticate the Codex CLI (`codex` on `PATH`). Parallax validates Codex with `plx-preflight --repo <repo> --require-codex`, where `<repo>` is the absolute repo root the orchestrator resolves during Bootstrap.

Parallax runs Codex only through `bin/plx-codex-ro`, which uses:

- `--ignore-user-config`
- explicit read-only sandboxing
- `--ephemeral`
- stdout output mode for normal lane calls
- temporary output/log files only when a caller needs separate debug files
- `--effort low|medium|high|xhigh` (default `high`; the dev pipeline runs planners and reviewers at `xhigh`)

`gpt-5.3-codex` is not available on some ChatGPT-account Codex auth. Parallax uses Codex with `gpt-5.5`. By default Codex is **read-only** (`bin/plx-codex-ro`) for plan and review lanes; it only *writes* when you opt in via `code: codex` (or `/plx:codex`), which routes through `bin/plx-codex-rw` (scoped `workspace-write` sandbox). Neither wrapper uses `danger-full-access` or `--yolo`.

## Grok

Install and authenticate the Grok CLI (`grok login`, or set `XAI_API_KEY`) to enable the `/plx:grok` passthrough (and Grok lanes in any pipeline configured to use them — parked for the future ultra tiers). Verified with grok 0.2.32 (`grok-composer-2.5-fast`); final-message extraction and headless permission behavior re-verified with 0.2.39.

Grok runs through two wrappers, both pinning a kernel-enforced sandbox (Seatbelt on macOS, Landlock on Linux):

- **`bin/plx-grok-ro`** — every review/plan lane. `--sandbox read-only`: grok may read but cannot write the repo (OS-denied). This is the read-only guarantee.
- **`bin/plx-grok-rw`** — opt-in writer (`code: grok` or `/plx:grok`). `--sandbox workspace`: edits are confined to the repo; writes outside are kernel-denied and logged to `~/.grok/sandbox-events.jsonl`.

Both pass `--permission-mode bypassPermissions`, because grok's CLI only *enforces* that mode (and `default`) — `acceptEdits`/`plan` are accepted but unenforced and would cancel the turn in headless. Confinement comes from the sandbox, not the permission mode.

Both wrappers emit only the model's final message (recovered from grok's session store, since the JSON envelope aggregates narration and subagent streams) and delete the run's `~/.grok/sessions` entry on success (kept on failure for debugging — grok has no `--ephemeral`). The CLI's `--effort` flag is not exposed: `grok-composer-2.5-fast` rejects the `reasoningEffort` parameter (API 400) and the run fails.

When invoking either wrapper from Claude Code, disable the Claude Bash sandbox for that call only (grok needs network/keychain access the sandbox blocks). The wrappers decide success from grok's `stopReason` + output and exit accordingly: **0** = ok, **3** = not signed in (run `grok login`), **1** = real failure. grok prints non-fatal `AuthorizationRequired` worker lines to stderr even on success — these are noise; judge by the exit code.

## Verification Toolchain

The orchestrator and `worker` run the target repo's own checks directly, such as `.venv/bin/ruff check .`, `.venv/bin/pytest -q`, `npm test`, `cargo test`, or `go test`.

Never use `uv run` inside a sandbox; Homebrew `uv` can panic there.

## Runtime State

Parallax does not use repo-local runtime state in v0.1.

It does not create:

```text
.parallax/
.parallax/cache/
.parallax/runs/
```

Intake prints repo metadata to stdout. Preflight and external reviewer wrappers may use `mktemp -d` internally for CLI prompt/output/log files, but those directories are removed before the command returns. Final results are returned in chat.
