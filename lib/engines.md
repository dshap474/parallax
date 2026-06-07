# Engine cookbook

Every PLX mode assigns pipeline roles to **engines**. This file is the one place that holds *how to invoke each engine*. **The role→engine binding lives in `config/parallax.yaml`**, per mode — that is where you swap which engine fills a role. This file holds *how to invoke* each engine; **to add a model**, add an engine block here and reference its name from `parallax.yaml`.

Parallax ships these engines, each surfaced as a **named subagent** so the Claude TUI shows which engine ran a lane: `claude-orch` (the orchestrator — you), `claude-reviewer` / `claude-worker` (Claude lanes), `codex-reviewer` / `codex-worker` (Codex CLI, wrapping `codex-ro.sh` / `codex-rw.sh`), and `grok-reviewer` / `grok-worker` (Grok CLI — the optional "Composer" Grok tier, wrapping `grok-ro.sh` / `grok-rw.sh`). The `-reviewer` subagents are read-only; the `-worker` subagents are write-capable and are used **only** when `parallax.yaml` assigns the writer (`code`) role to that engine.

## Safety (non-negotiable)

- **Role determines access, not engine.** Review and plan roles (plan-review, debug, correctness, refine *advisors*, plan panel) are **always read-only** for every engine. Only the writer (`code`) role gets write access, and exactly one engine fills it per mode.
- **Codex review:** every review call must go through `scripts/codex-ro.sh` (`--ignore-user-config` + explicit read-only sandbox). Never inherit the user's global Codex config — it may default to full access.
- **Grok / Composer review:** every review call must go through `scripts/grok-ro.sh` (plan permission mode + `--cwd`). Never pass `--yolo`.
- **Non-Claude writer:** when `parallax.yaml` sets `code` to `codex`/`grok`, the writer call goes through `scripts/codex-rw.sh` (scoped `workspace-write` sandbox, `--ignore-user-config`) or `scripts/grok-rw.sh` (`acceptEdits` permission mode, `--cwd`). These write **only** within the target repo. Never `danger-full-access`, never `bypassPermissions`/`--yolo`, never `--dangerously-bypass-approvals-and-sandbox`. With the default config the writer is always Claude and these wrappers are never invoked.
- Do not write Parallax state into the target repo. Use wrapper `--stdout` modes or shell temp directories created with `mktemp -d`, then clean them up before returning.

## Preflight (run once, before Stage 1)

Fail fast instead of discovering a broken engine mid-pipeline:

- **CLI present:** run `${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh --repo <repo> ...` after `router.md` selects the candidate mode.
- **Model available:** `preflight.sh` runs cheap probes with temporary files and prints the result to stdout. A 400 means that model isn't available on this auth — switch models before proceeding.
- **Degrade gracefully:** if an optional engine is absent, drop its review lane and say so — never crash the run.

## Verification (who runs the repo's checks)

The orchestrator (and `worker` when self-verifying) runs the repo's existing checks directly: **`.venv/bin/ruff check .`, `.venv/bin/pytest -q`**, etc. **Never `uv run` inside a sandbox** — Homebrew `uv` panics there (`Attempted to create a NULL object`). Use the venv binaries straight. (Adapt to the target repo's toolchain — npm, cargo, go, etc.)

## Timing (optional, for cost/latency measurement)

To measure a run, bracket each wrapper call and keep the token line the engine already prints in the wrapper log.
Report per-stage seconds + tokens in the final chat summary. This isolates engine time from orchestrator time — the only honest combo cost comparison.

## Output discipline

Feed only each engine's **final text** back to the orchestrator — never the raw event/JSON envelope. The envelope (`thought`, `sessionId`, `requestId`, `stopReason`, event frames) wastes input tokens and adds noise.

- **codex** → prefer `scripts/codex-ro.sh --stdout`; otherwise point `--out` and `--log` at a temp directory and delete it after reading. Don't use `--json` (JSONL events).
- **grok / composer** → prefer `scripts/grok-ro.sh --stdout`; otherwise point `--out` and `--log` at a temp directory and delete it after reading. Don't use JSON unless a future wrapper explicitly supports it.

---

## Engines

### `claude-orch` — orchestrator (planner / synthesizer / direct-editor)
The main Claude agent. Not a CLI — it is *you*. Plans (Stage 1), reconciles plan-review, synthesizes review findings into specs/plans, and applies edits with `Edit`/`Write`. The only engine that is "you".

### `claude-reviewer` — fresh Claude reviewer / advisor (read-only)
A fresh Claude subagent via the **Agent tool**, using Parallax's bundled **`claude-reviewer`** agent (shows as `plx:claude-reviewer`; read-only: Read/Glob/Grep). Pass it only neutral context + the lane brief (Neutral Context Rule). Returns findings; never edits.

### `claude-worker` — fresh Claude coder (write)
A fresh, write-capable Claude subagent via the **Agent tool**, using Parallax's bundled **`claude-worker`** agent (`plx:claude-worker`). Used for the **Code** stage in modes that delegate writing (ultra): hand it the per-task spec **only** (neutral — no orchestrator analysis, no review history), let it implement, then it de-spawns. Keeps the orchestrator's context lean and the first pass uncontaminated. It may run the repo's checks to self-verify — with the repo's venv/toolchain binaries, never `uv run` (see Verification). In **quick and team the orchestrator writes directly** and does not spawn `claude-worker`.

### `codex-ro` — Codex reviewer / advisor (read-only)
Runs **inside the `plx:codex-reviewer` subagent** (so the TUI shows the Codex lane): the orchestrator prepares the prompt and hands the subagent the command `${CLAUDE_PLUGIN_ROOT}/scripts/codex-ro.sh --repo <REPO> --prompt <PROMPT.md> --stdout`. Bump/keep `--effort high` for review work. If you need separate logs for debugging, use `--out` and `--log` inside a temp directory and clean it up.

> **Availability caveat:** `gpt-5.3-codex` is **not available** on a ChatGPT-account Codex auth (API 400). Parallax runs Codex with `gpt-5.5` — confirm it with the preflight probe.

### `codex-rw` — Codex writer (write, opt-in)
Used **only** when `parallax.yaml` sets `code: codex`, runs **inside the `plx:codex-worker` subagent**. Use `${CLAUDE_PLUGIN_ROOT}/scripts/codex-rw.sh --repo <REPO> --prompt <SPEC.md> --stdout`. Same flags as `codex-ro` but with a scoped `workspace-write` sandbox — Codex edits files in `<REPO>` and nowhere else. Feed it the per-task spec only (neutral context), then the orchestrator reviews the diff exactly as it would review a `worker`'s output.

### `grok-ro` — Grok ("Composer") read-only (verified 2026-06-03, grok 0.2.16)
Used by the `ultra-dev` pipeline (and any pipeline configured with Grok review lanes), runs **inside the `plx:grok-reviewer` subagent**. Read-only via the `grok-ro.sh` wrapper. Plain output is just the model's final message.
- **The orchestrator must disable its own Bash sandbox for this wrapper call.** Inside a sandboxed shell, grok's workers die with `Transport channel closed / AuthorizationRequired` and the run silently no-ops (exit 0, **no output**). In Claude Code, pass `dangerouslyDisableSandbox: true` on the Bash call.
- **Verify by the output, not stderr.** Even on success, grok prints non-fatal `AuthorizationRequired` worker lines to stderr (background workers) — ignore them; the main worker completes and the final message lands on stdout.
- **Verified:** plan-mode review returns a clean findings list and writes nothing (confirmed: target file unchanged, no new files). This is the read-only reviewer for the Grok tier.

### `grok-rw` — Grok writer (write, **unsupported**) — `plx:grok-worker`
> **Status (verified 2026-06-04, grok 0.2.16): `code: grok` does not work.** Grok's file-editing runs in background workers that die with `AuthorizationRequired / Transport channel closed` even with the Bash sandbox disabled, so writes silently produce no edits. `scripts/grok-rw.sh` exists and **fails loudly** on that signature rather than reporting phantom success. Use `code: claude` or `code: codex` for the writer. Grok remains fully usable as a read-only **reviewer** (`grok-ro`), where only the main worker's text is needed.

If the grok-CLI auth issue is later fixed: `${CLAUDE_PLUGIN_ROOT}/scripts/grok-rw.sh --repo <REPO> --prompt <SPEC.md> --stdout` mirrors `grok-ro` but with `--permission-mode acceptEdits` instead of `plan`, and the same Bash-sandbox caveat applies (`dangerouslyDisableSandbox: true`).

---

## Notes on swapping

- Swap engines per role in `config/parallax.yaml` (`modes.<mode>.<role>`), not in this file. This file only documents *how* each engine is invoked.
- Reasoning/effort defaults live in each block above; a roster may note a per-combo override.
- The **role**, not the engine, is what the pipeline references. The writer (`code`) role takes one engine and is the only role that edits; review/plan roles take a list and are always read-only. Any model can fill any role within those constraints.
