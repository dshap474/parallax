# Engine cookbook

Every combo assigns pipeline roles to **engines** (see the combo's ENGINE ROSTER). This file is the one place that holds *how to invoke each engine*. **To swap a model** for a role, point that roster row at a different engine here, or edit the engine's block. **To add a model**, add a new engine block here and reference it from a roster.

Polyphony ships five engines: `claude-orch`, `reviewer`, `worker` (Claude), `codex-ro` (Codex CLI), and `composer-ro` (Grok CLI — **v0.2 tier**, see below).

## Safety (non-negotiable)

- **Codex:** every call carries `--ignore-user-config` **and** an explicit `--sandbox`. Never inherit the user's global Codex config — it may default to full access.
- **Grok / Composer:** set the permission flag explicitly on every call — never inherit `~/.grok/config.toml`. Polyphony only ever runs Grok **read-only** (`--permission-mode plan` or `--disallowed-tools`); contain the blast radius with `--cwd`. Never pass `--yolo` (it drops the FS/network sandbox).
- **Read-only roles** (plan-review, debug, correctness, refine *advisors*) use a read-only / plan sandbox. Only **writer roles** (Code, and the orchestrator's direct edits) get write access — and in Polyphony the only writers are Claude.
- Work artifacts go in the repo-local `.polyphony/` dir (gitignore it). Prompts in, engine output captured to a file you then read.

## Preflight (run once, before Stage 1)

Fail fast instead of discovering a broken engine mid-pipeline:

- **CLI present:** `command -v codex` (required). `command -v grok` only if the combo uses the Grok tier (`ultra-dev`, or `team-dev`'s optional panel).
- **Model available:** one cheap probe before trusting a model — e.g. `codex exec --ignore-user-config --sandbox read-only --skip-git-repo-check -m gpt-5.5 -c model_reasoning_effort=low --ephemeral -o /tmp/poly-probe.md - <<< "reply OK"` then read `/tmp/poly-probe.md`. A 400 means that model isn't available on this auth — switch models before proceeding.
- **Degrade gracefully:** if an optional engine is absent, drop its review lane and say so — never crash the run.

## Verification (who runs the repo's checks)

The orchestrator (and `worker` when self-verifying) runs the repo's existing checks directly: **`.venv/bin/ruff check .`, `.venv/bin/pytest -q`**, etc. **Never `uv run` inside a sandbox** — Homebrew `uv` panics there (`Attempted to create a NULL object`). Use the venv binaries straight. (Adapt to the target repo's toolchain — npm, cargo, go, etc.)

## Timing (optional, for cost/latency measurement)

To measure a run, bracket each CLI call and keep the token line the engine already prints:
```bash
s=$(date +%s); codex exec … -o OUT.md - < PROMPT.md > LOG 2>&1; echo "codex <lane>: $(( $(date +%s) - s ))s"
grep -A1 "tokens used" LOG   # codex prints its own token count
```
Record per-stage seconds + tokens in the run's `results.md`. This isolates engine time from orchestrator time — the only honest combo cost comparison.

## Output discipline

Feed only each engine's **final text** back to the orchestrator — never the raw event/JSON envelope. The envelope (`thought`, `sessionId`, `requestId`, `stopReason`, event frames) wastes input tokens and adds noise.

- **codex** → read **only** the `-o/--output-last-message <FILE>` (the final message). codex *also* prints a banner + config block + prompt echo + `tokens used` line to **stdout** — redirect stdout to a log (`> .polyphony/<task>.log 2>&1`) so that noise never reaches the orchestrator. Don't use `--json` (JSONL events).
- **grok / composer** → use plain output (the default) and capture stdout. Don't use `--output-format json` unless you specifically need `stopReason` — then extract the text with `jq -r '.text'`.

---

## Engines

### `claude-orch` — orchestrator (planner / synthesizer / direct-editor)
The main Claude agent. Not a CLI — it is *you*. Plans (Stage 1), reconciles plan-review, synthesizes review findings into specs/plans, and applies edits with `Edit`/`Write`. The only engine that is "you".

### `reviewer` — fresh Claude reviewer / advisor (read-only)
A fresh Claude subagent via the **Agent tool**, using Polyphony's bundled **`reviewer`** agent (shows as `polyphony:reviewer`; read-only: Read/Glob/Grep). Pass it only neutral context + the lane brief (Neutral Context Rule). Returns findings; never edits.

### `worker` — fresh Claude coder (write)
A fresh, write-capable Claude subagent via the **Agent tool**, using Polyphony's bundled **`worker`** agent (`polyphony:worker`). Used for the **Code** stage in Claude-writer combos: hand it the per-task spec **only** (neutral — no orchestrator analysis, no review history), let it implement, then it de-spawns. Keeps the orchestrator's context lean and the first pass uncontaminated. It may run the repo's checks to self-verify — with the repo's venv/toolchain binaries, never `uv run` (see Verification). For a small task, the orchestrator may write directly and skip the worker.

### `codex-ro` — Codex reviewer / advisor (read-only)
```bash
codex exec --ignore-user-config --sandbox read-only --skip-git-repo-check \
  -C <REPO> -m gpt-5.5 -c model_reasoning_effort=high --ephemeral \
  -o <OUT.md> - < <PROMPT.md> > .polyphony/<task>.log 2>&1
```
**Read only `<OUT.md>`** — redirect stdout (banner / config / prompt echo / `tokens used`) to a log so it never reaches the orchestrator. Bump/keep `model_reasoning_effort=high` for review work.

> **Availability caveat:** `gpt-5.3-codex` is **not available** on a ChatGPT-account Codex auth (API 400). Polyphony only runs Codex **read-only** with `gpt-5.5`, so there is no writer-model availability risk — confirm `gpt-5.5` with the preflight probe.

### `composer-ro` — Grok Composer read-only (**v0.2 tier — stub, verify before use**)
Used by `ultra-dev` and `team-dev`'s optional Grok panel. **Not used by `team-dev`'s default codex-only combo.** Invoke read-only — `--permission-mode plan` (no edits) or strip edit tools via `--disallowed-tools`:
```bash
grok --cwd <REPO> --permission-mode plan --prompt-file <PROMPT.md> > <OUT.txt> 2>/dev/null
```
- **The orchestrator must disable its own Bash sandbox for this call.** Inside a sandboxed shell, grok's workers die with `Transport channel closed / AuthorizationRequired` and the run silently no-ops (exit 0, **no file**). In Claude Code, pass `dangerouslyDisableSandbox: true` on the Bash call.
- `AuthorizationRequired` lines on stderr are non-fatal noise. Verify success by the written file, not by stderr being clean.
- **This block is a stub:** smoke-test grok's read-only behavior on your install before relying on it. Until verified, run `team-dev`'s default codex-only combo. (Tracked for v0.2.)

---

## Notes on swapping

- Reasoning/effort defaults live in each block above; a roster may note a per-combo override.
- The **role**, not the engine, is what the pipeline references. As long as a writer role points at a writer engine and a review role points at a read-only engine, any model can fill any role.
