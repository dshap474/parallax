# Requirements and setup

Parallax orchestrates local engine CLIs; it does not host or proxy models.

| Host package | Required host | Required pipeline engines | Optional |
| --- | --- | --- | --- |
| Claude Code | authenticated `claude` | authenticated `codex` | `grok`, `gemini`, `devin` |
| Codex | authenticated `codex` | authenticated `claude` | `grok`, `gemini`, `devin` |

The Codex CLI and Claude Code CLI must be available on `PATH`. Review and Simplify
use the opposite engine by default. Grok overrides and the Grok passthrough use
Grok 4.6 and require a current CLI and `grok login` or `XAI_API_KEY`. The Gemini
passthrough requires `@google/gemini-cli`, authentication via `gemini`, and macOS. The
Devin passthrough requires the Devin CLI and `devin auth login`. No pipeline requires
Grok, Gemini, or Devin.

## Engine contract

All packages invoke `bin/plx-engine` with:

```text
plx-engine --engine codex|claude|grok|gemini --mode ro|rw --repo <absolute-path> \
  --prompt-file <file> [--rubric <name>] [--model <model>] [--effort <level>] \
  (--stdout | --out <file> --log <file>)
```

Devin uses the same wrapper with its explicit transport contract:

```text
plx-engine --engine devin --mode full-access --repo <absolute-path> \
  --prompt-file <file> [--model <exact-model-id>] \
  (--stdout | --out <file> --log <file>)
```

Exit codes are `0` success, `1` engine failure, `2` usage error, `3` authentication
required, and `4` a retryable Devin protocol failure. Long engine calls should run in a
retained or background shell. Per-engine sandbox and permission settings are described
in [Architecture](ARCHITECTURE.md#runtime-and-safety).

## Local development install

From the repository root:

```text
claude plugin marketplace add .
claude plugin install plx@parallax-marketplace

codex plugin marketplace add .
codex plugin add plx@parallax-marketplace
```

Start a new host session after installing or updating so new skills and tools are loaded.
