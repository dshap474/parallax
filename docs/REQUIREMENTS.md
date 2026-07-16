# Requirements and setup

Parallax orchestrates local engine CLIs; it does not host or proxy models.

| Host package | Required host | Required default lane engine | Optional |
| --- | --- | --- | --- |
| Claude Code | authenticated `claude` | authenticated `codex` | `grok` |
| Codex | authenticated `codex` | authenticated `claude` | `grok` |

The Codex CLI and Claude Code CLI must be available on `PATH`. Grok 4.5 requires a
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
and model availability.

Long engine calls should run in a retained/background shell session. Grok may require
narrowly scoped host approval for network or keychain access; its own kernel sandbox
remains the file-confinement boundary.

## Local development install

From the repository root:

```text
claude plugin marketplace add .
claude plugin install plx@parallax-marketplace

codex plugin marketplace add .
codex plugin add plx@parallax-marketplace
```

Start a new host session after installing or updating so new skills and tools are loaded.
