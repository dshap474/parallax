# Requirements & setup

Polyphony **orchestrates external model CLIs that you install and authenticate** — it does
not bundle, host, or proxy any model. You bring your own `codex` (and, for the Grok tier,
`grok`) and your own credentials.

## Tiers

| Tier | Install | Enables | Status |
|---|---|---|---|
| **0 — default** | `codex` CLI + auth | `team-dev` (full cross-model review) | **v0.1, supported** |
| **1 — Grok** | + `grok` CLI + auth | `ultra-dev`, `team-dev`'s optional review panel | **v0.2** |

You can run the entire `team-dev` pipeline with only Tier 0.

## Codex CLI (required)

1. Install the OpenAI Codex CLI and authenticate it (`codex` on your PATH; `codex login` or
   API-key auth per its docs).
2. Verify: `command -v codex` and the preflight probe below.

**Availability caveat:** `gpt-5.3-codex` is **not available** on a ChatGPT-account Codex
auth (API returns 400). Polyphony sidesteps this entirely — it only ever runs Codex
**read-only** with `gpt-5.5`, so there is no writer-model dependency. Confirm `gpt-5.5`
with the probe.

**Preflight probe** (cheap, run once before a pipeline):

```bash
codex exec --ignore-user-config --sandbox read-only --skip-git-repo-check \
  -m gpt-5.5 -c model_reasoning_effort=low --ephemeral -o /tmp/poly-probe.md - <<< "reply OK"
cat /tmp/poly-probe.md
```

A 400 means `gpt-5.5` isn't available on your auth — fix that before relying on Codex.

## Grok CLI (Grok tier, v0.2)

`ultra-dev` and `team-dev`'s optional panel use Grok read-only via the `composer-ro`
engine. **This engine is currently a stub** (`references/engines.md`) — smoke-test grok's
read-only behavior on your install before relying on it. Two known headless gotchas:

- **Disable the orchestrator's Bash sandbox for grok calls.** Inside a sandboxed shell,
  grok's workers die (`Transport channel closed / AuthorizationRequired`) and the run
  silently no-ops (exit 0, no output file). In Claude Code, pass
  `dangerouslyDisableSandbox: true` on the Bash call.
- **Verify by the output file, not stderr.** `AuthorizationRequired` lines on stderr are
  non-fatal noise; success = the written output file exists.

## Safety model (how Polyphony invokes the CLIs)

These are non-negotiable and baked into `references/engines.md`:

- **Codex:** every call carries `--ignore-user-config` **and** an explicit `--sandbox
  read-only`. Polyphony never inherits your global Codex config (which may grant full
  access) and never lets Codex write.
- **Grok:** invoked read-only (`--permission-mode plan` / `--disallowed-tools`), confined
  with `--cwd`, never `--yolo`.
- **Reviewers are read-only by construction** — they run in read-only sandboxes and cannot
  edit the repo. Only Claude (the orchestrator or the bundled `worker`) ever writes.
- **Work artifacts** go in a repo-local `.polyphony/` directory (add it to `.gitignore`;
  the plugin ships a `.gitignore` entry).

## Verification toolchain

The orchestrator and `worker` run **the target repo's own checks** to verify changes —
e.g. `.venv/bin/ruff check .`, `.venv/bin/pytest -q`, or `npm test`, `cargo test`, `go
test`. **Never `uv run` inside a sandbox** — Homebrew `uv` panics there. Use the venv /
toolchain binaries directly. Adapt to whatever the repo provides.

## Graceful degradation

The preflight detects which engines are present. A missing **optional** engine (e.g. the
second debug reviewer, or grok) drops that lane with a logged note — it does not crash the
run. A missing **required** engine (`codex` for `team-dev`) stops the run with a clear
message.
