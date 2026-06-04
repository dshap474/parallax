# Engine cookbook

Every LLX mode assigns pipeline roles to **engines**. This file is the one place that holds *how to invoke each engine*. **To swap a model** for a role, point that mode row at a different engine here, or edit the engine's block. **To add a model**, add a new engine block here and reference it from `modes.md`.

Parallax ships five engines: `claude-orch`, `reviewer`, `worker` (Claude), `codex-ro` (Codex CLI), and `composer-ro` / `grok-ro` (Grok CLI — optional Grok tier, see below).

## Safety (non-negotiable)

- **Codex:** every call must go through `scripts/codex-ro.sh`. The wrapper carries `--ignore-user-config` and an explicit read-only sandbox. Never inherit the user's global Codex config — it may default to full access.
- **Grok / Composer:** every call must go through `scripts/grok-ro.sh`. The wrapper uses plan permission mode and `--cwd`. Never pass `--yolo`.
- **Read-only roles** (plan-review, debug, correctness, refine *advisors*) use a read-only / plan sandbox. Only **writer roles** (Code, and the orchestrator's direct edits) get write access — and in Parallax the only writers are Claude.
- Work artifacts go in the absolute run directory created by Parallax intake under `.parallax/runs/<run-id>/`. Prompts in, engine output captured to a file you then read.

## Preflight (run once, before Stage 1)

Fail fast instead of discovering a broken engine mid-pipeline:

- **CLI present:** run `${CLAUDE_SKILL_DIR}/scripts/preflight.sh --run-dir <run-dir> ...` after `router.md` selects the candidate mode.
- **Model available:** `preflight.sh` runs per-run cheap probes and writes `preflight.md` plus `preflight.env`. A 400 means that model isn't available on this auth — switch models before proceeding.
- **Degrade gracefully:** if an optional engine is absent, drop its review lane and say so — never crash the run.

## Verification (who runs the repo's checks)

The orchestrator (and `worker` when self-verifying) runs the repo's existing checks directly: **`.venv/bin/ruff check .`, `.venv/bin/pytest -q`**, etc. **Never `uv run` inside a sandbox** — Homebrew `uv` panics there (`Attempted to create a NULL object`). Use the venv binaries straight. (Adapt to the target repo's toolchain — npm, cargo, go, etc.)

## Timing (optional, for cost/latency measurement)

To measure a run, bracket each wrapper call and keep the token line the engine already prints in the wrapper log.
Record per-stage seconds + tokens in the run's `results.md`. This isolates engine time from orchestrator time — the only honest combo cost comparison.

## Output discipline

Feed only each engine's **final text** back to the orchestrator — never the raw event/JSON envelope. The envelope (`thought`, `sessionId`, `requestId`, `stopReason`, event frames) wastes input tokens and adds noise.

- **codex** → read only the output file from `scripts/codex-ro.sh`; logs stay in `<run-dir>/logs/`. Don't use `--json` (JSONL events).
- **grok / composer** → read only the output file from `scripts/grok-ro.sh`; logs stay in `<run-dir>/logs/`. Don't use JSON unless a future wrapper explicitly supports it.

---

## Engines

### `claude-orch` — orchestrator (planner / synthesizer / direct-editor)
The main Claude agent. Not a CLI — it is *you*. Plans (Stage 1), reconciles plan-review, synthesizes review findings into specs/plans, and applies edits with `Edit`/`Write`. The only engine that is "you".

### `reviewer` — fresh Claude reviewer / advisor (read-only)
A fresh Claude subagent via the **Agent tool**, using Parallax's bundled **`reviewer`** agent (shows as `parallax:reviewer`; read-only: Read/Glob/Grep). Pass it only neutral context + the lane brief (Neutral Context Rule). Returns findings; never edits.

### `worker` — fresh Claude coder (write)
A fresh, write-capable Claude subagent via the **Agent tool**, using Parallax's bundled **`worker`** agent (`parallax:worker`). Used for the **Code** stage in team/panel/ultra mode: hand it the per-task spec **only** (neutral — no orchestrator analysis, no review history), let it implement, then it de-spawns. Keeps the orchestrator's context lean and the first pass uncontaminated. It may run the repo's checks to self-verify — with the repo's venv/toolchain binaries, never `uv run` (see Verification). For a quick task, the orchestrator may write directly and skip the worker.

### `codex-ro` — Codex reviewer / advisor (read-only)
Use `${CLAUDE_SKILL_DIR}/scripts/codex-ro.sh --repo <REPO> --prompt <PROMPT.md> --out <OUT.md> --log <LOG>`. **Read only `<OUT.md>`**. Bump/keep `--effort high` for review work.

> **Availability caveat:** `gpt-5.3-codex` is **not available** on a ChatGPT-account Codex auth (API 400). Parallax only runs Codex **read-only** with `gpt-5.5`, so there is no writer-model availability risk — confirm `gpt-5.5` with the preflight probe.

### `composer-ro` / `grok-ro` — Grok Composer read-only (verified 2026-06-03, grok 0.2.16)
Used by `llx` panel and ultra modes. Read-only via the `grok-ro.sh` wrapper. Plain output is just the model's final message.
- **The orchestrator must disable its own Bash sandbox for this wrapper call.** Inside a sandboxed shell, grok's workers die with `Transport channel closed / AuthorizationRequired` and the run silently no-ops (exit 0, **no output**). In Claude Code, pass `dangerouslyDisableSandbox: true` on the Bash call.
- **Verify by the output, not stderr.** Even on success, grok prints non-fatal `AuthorizationRequired` worker lines to stderr (background workers) — ignore them; the main worker completes and the final message lands on stdout.
- **Verified:** plan-mode review returns a clean findings list and writes nothing (confirmed: target file unchanged, no new files). This is the read-only reviewer for the Grok tier.

---

## Notes on swapping

- Reasoning/effort defaults live in each block above; a roster may note a per-combo override.
- The **role**, not the engine, is what the pipeline references. As long as a writer role points at a writer engine and a review role points at a read-only engine, any model can fill any role.
