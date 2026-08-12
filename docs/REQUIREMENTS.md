# Requirements and setup

Parallax orchestrates local engine CLIs; it does not host or proxy models.

| Host package | Required host | Required default lane engine | Optional |
| --- | --- | --- | --- |
| Claude Code | authenticated `claude` | authenticated `codex` | `grok` |
| Codex | authenticated `codex` | authenticated `claude` | `grok` |

The Codex CLI and Claude Code CLI must be available on `PATH`. Grok 4.6 requires a
current Grok CLI and `grok login` or `XAI_API_KEY`.

## Engine contract

All packages invoke `bin/plx-engine` with:

```text
plx-engine --engine codex|claude|grok --mode ro|rw --repo <absolute-path> \
  --prompt-file <file> [--rubric <name>] [--model <model>] [--effort <level>] \
  (--stdout | --out <file> --log <file>)
```

Exit codes are `0` success, `1` engine failure, `2` usage error, and `3` authentication
required. `plx-preflight` sends a minimal real prompt to prove install, authentication,
model availability, and the selected sandbox profile. Grok writer selection uses
`--grok-mode rw`, which probes its workspace sandbox against a disposable directory
rather than the target repository.

Long engine calls should run in a retained/background shell session. Grok may require
narrowly scoped host approval for network or keychain access; its own kernel sandbox
remains the file-confinement boundary. A sandbox-initialization failure is named
`PLX_GROK_SANDBOX_UNAVAILABLE` and never authorizes host-session substitution.

## Optional trace capture

Set `PLX_TRACE_DB` to an absolute SQLite path to collect local schema-v1 skill runs and
engine lanes via `plx-eval`. An explicit process value wins. When it is unset, `plx-eval`
reads the literal assignment from `~/.config/parallax/env` (or
`$XDG_CONFIG_HOME/parallax/env`); that file may symlink to a git-ignored checkout `.env`.
The loader does not execute shell syntax. When neither source defines the variable,
capture is fully disabled. Records include complete prompts, engine logs, final outputs,
tasks, and run metadata; protect the database accordingly. `plx-eval doctor` reports
disabled or validates schema and integrity. Recording is best-effort and never alters
engine exit codes. Parallax does not add hooks, telemetry services, MCP servers, or
`.parallax/` state in target repos.

## Local development install

From the repository root:

```text
claude plugin marketplace add .
claude plugin install plx@parallax-marketplace

codex plugin marketplace add .
codex plugin add plx@parallax-marketplace
```

Start a new host session after installing or updating so new skills and tools are loaded.
