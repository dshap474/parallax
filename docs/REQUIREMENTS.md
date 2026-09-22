# Requirements and setup

Parallax orchestrates local engine CLIs; it does not host or proxy models.

| Host package | Required host | Required pipeline engines | Optional |
| --- | --- | --- | --- |
| Claude Code | authenticated `claude` | authenticated `codex` and `grok` | `devin` |
| Codex | authenticated `codex` | authenticated `claude` and `grok` | `devin` |

The Codex CLI and Claude Code CLI must be available on `PATH`. Review uses Grok 4.5;
Simplify and the Grok passthrough use Grok 4.6. Grok requires a current CLI and
`grok login` or `XAI_API_KEY`.
`/plx:devin` and `$plx:devin` additionally require the Devin CLI and
`devin auth login`; Devin is not required by existing pipelines or preflight checks.

## Engine contract

All packages invoke `bin/plx-engine` with:

```text
plx-engine --engine codex|claude|grok --mode ro|rw --repo <absolute-path> \
  --prompt-file <file> [--rubric <name>] [--model <model>] [--effort <level>] \
  (--stdout | --out <file> --log <file>)
```

Devin uses the same wrapper with its explicit transport contract:

```text
plx-engine --engine devin --mode full-access --repo <absolute-path> \
  --prompt-file <file> [--model <exact-model-id>] \
  (--stdout | --out <file> --log <file>)
```

Exit codes are `0` success, `1` engine failure, `2` usage error, and `3` authentication
required. `plx-preflight` sends a minimal real prompt to prove install, authentication,
model availability, and the selected sandbox profile. Pass `--model <id>` when a skill
selects a specific model so preflight checks that model. Grok writer selection uses
`--grok-mode rw`, which probes its workspace sandbox against a disposable directory
rather than the target repository.

Codex runs ephemerally with `approval_policy=never` and a selected sandbox; it never uses
the combined approvals-and-sandbox bypass. Claude runs in safe mode with ambient plugins,
hooks, MCP servers, and automatic project customization disabled, so `plx-engine` lists
the repository guidance files the lane must apply. Grok's `bypassPermissions` is an
unattended approval mode, separate from its read-only or workspace filesystem sandbox.

Normal lanes remain read-only or workspace-constrained. The one standalone Build writer
uses the explicit full-access transport needed for repository Git metadata and packaged
review launches: Codex `danger-full-access`, or Claude's sandbox-disabled permission
bypass. The wrapper rejects that mode outside an `rw` `worker`/`build-worker` lane, and
the transport does not grant publication or external-system authority.

Devin is intentionally different: the wrapper selects dangerous permission mode and no
OS sandbox, so it has full filesystem and network access. The generated user config
disables supported imports, automatic updates, and subagents, but repository-native
hooks, MCP servers, rules, and skills may still load. The wrapper appends a deterministic
list of ignored, untracked, and nested repository guidance, validates the terminal ATIF
response, never retries a possibly mutating task, and stops its owned process group on
interruption. Full access does not grant publication or external-system authority.

Long engine calls should run in a retained/background shell session. Grok may require
narrowly scoped host approval for network or keychain access; its own kernel sandbox
remains the file-confinement boundary. A sandbox-initialization failure is named
`PLX_GROK_SANDBOX_UNAVAILABLE` and never authorizes host-session substitution.

## Optional trace capture

Set `PLX_TRACE_DB` to an absolute SQLite path to collect local schema-v2 skill runs and
engine lanes via `plx-eval`. An explicit process value wins. When it is unset, `plx-eval`
reads the literal assignment from `~/.config/parallax/env` (or
`$XDG_CONFIG_HOME/parallax/env`); that file may symlink to a git-ignored checkout `.env`.
The loader does not execute shell syntax. When neither source defines the variable,
capture is fully disabled. Records include complete prompts, engine logs, final outputs,
tasks, and run metadata; protect the database accordingly. `plx-eval doctor` reports
disabled or validates schema and integrity. Recording is best-effort and never alters
engine exit codes. Existing schema-v1 databases migrate in place on first use. Parallax
does not add hooks, telemetry services, MCP servers, or
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
