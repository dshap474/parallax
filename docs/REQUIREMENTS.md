# Requirements & Setup

Parallax orchestrates external model CLIs that you install and authenticate. It does not bundle, host, or proxy any model.

## Tiers

| Tier | Install | Enables | Required? |
|---|---|---|---|
| Codex | `codex` CLI + auth | `plx` team mode | required for default multi-model mode |
| Grok | `grok` CLI + auth | `plx` panel/ultra modes | optional |

Quick mode can run without Codex. Team mode requires Codex. Panel degrades if Grok is missing. Ultra requires Codex and Grok unless the run is explicitly degraded.

## Codex

Install and authenticate the Codex CLI (`codex` on `PATH`). Parallax validates Codex per run with `skills/plx/scripts/preflight.sh --run-dir <run-dir> --require-codex`, where `<run-dir>` is the absolute path printed by intake.

Parallax runs Codex only through `skills/plx/scripts/codex-ro.sh`, which uses:

- `--ignore-user-config`
- explicit read-only sandboxing
- `--ephemeral`
- output captured to a file under `.parallax/runs/<run-id>/outputs/`
- logs captured under `<run-dir>/logs/`

`gpt-5.3-codex` is not available on some ChatGPT-account Codex auth. Parallax uses Codex as a read-only reviewer with `gpt-5.5`; there is no Codex writer dependency.

## Grok

Install and authenticate the Grok CLI (`grok` on `PATH`) to enable panel and ultra modes.

Parallax runs Grok only through `skills/plx/scripts/grok-ro.sh`, which uses plan permission mode and requires non-empty output to count as success. The wrapper writes stdout to the requested output file and stderr to a log.

When invoking the Grok wrapper from Claude Code, disable the Claude Bash sandbox for that wrapper call only. Existing verification showed Grok can silently no-op inside that sandbox while still exiting 0. Treat non-empty output as success; stderr may contain non-fatal worker noise.

## Verification Toolchain

The orchestrator and `worker` run the target repo's own checks directly, such as `.venv/bin/ruff check .`, `.venv/bin/pytest -q`, `npm test`, `cargo test`, or `go test`.

Never use `uv run` inside a sandbox; Homebrew `uv` can panic there.

## Run State

Parallax does not use a cache in v0.1. Every run writes to an absolute run directory under:

```text
<repo>/.parallax/runs/<run-id>/
```

Expected per-run files include `state.env`, `intake.md`, `preflight.env`, `preflight.md`, prompts, outputs, logs, findings, artifacts, and `results.md`.
