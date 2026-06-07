# Parallax pipeline (role-based)

Shared grammar for every PLX pipeline: role definitions, stage semantics, engine binding, and neutral-context rules. Each skill composes the stages below into an ordered pipeline (its "## Pipeline" section) and resolves engines from `config/parallax.yaml`; `lib/engines.md` holds how to invoke each engine.

**Roles:** Plan · Plan-review · Code · Refine · Debug review · Correctness review · Fix. Plan, plan/spec synthesis, and review/fix synthesis are always the orchestrator (`claude-orch`).

Parallax does not persist repo-local runtime state. Keep prompts, engine outputs, and findings in chat or temporary shell directories that are deleted before returning.

| # | Stage | Role | Edits repo? |
|---|---|---|---|
| 1 | Plan | orchestrator | no |
| 2 | Plan-review | Plan-review engine (read-only) | no |
| 3 | Code | Code engine (write) | **yes** |
| 4 | Refine | Refine role (direct *or* delegated) | **yes** |
| 5 | Review | Debug engine(s) + Correctness engine (read-only) | no |
| 6 | Fix | Fix role (direct *or* delegated) | **yes** |

---

## Engine binding & subagent injection

Before running a pipeline, resolve each role to its engine from `config/parallax.yaml` under the active pipeline's key. Review/plan roles take a **list** (one lane per engine); the `code` writer takes **exactly one** engine. A role absent from config falls back to the default named in the stage text.

Every lane runs as a **named subagent chosen by its resolved engine**, so the TUI shows which engine ran it:

- **Review / plan roles** (`plan`, `plan-review`, `review-debug`, `review-correctness`, `review-refine`) → `plx:<engine>-reviewer`, one per listed engine. Always **read-only**: `plx:claude-reviewer` reviews with its own model; `plx:codex-reviewer` / `plx:grok-reviewer` run the matching `*-ro.sh` wrapper. Never route a review/plan lane through a `*-rw.sh` wrapper.
- **Writer role** (`code`) → `plx:<engine>-worker`. `plx:codex-worker` / `plx:grok-worker` run the matching `*-rw.sh` wrapper, then the orchestrator reviews the diff. (`code: grok` is currently unsupported — `plx:grok-worker` fails loudly.)
  - **Exception:** when `code` is `claude` in a non-delegating pipeline (solo/team), the **orchestrator writes directly** — do not spawn `plx:claude-worker`. Delegating pipelines (ultra) use `plx:claude-worker`.

For `codex` / `grok` lanes the orchestrator prepares the neutral prompt (`scripts/make-review-prompt.sh` for reviews; the per-task spec for the writer) and hands the subagent the prompt path plus the exact wrapper command; the subagent only executes it and returns the output. When a subagent runs a `grok-*` wrapper through Bash, disable the Claude Bash sandbox for that call only.

## Shared rules

- Only the writer (`code`) role edits the repo; every other role is read-only.
- Review and plan lanes are read-only for every engine, including a non-Claude writer when it is acting as a reviewer.
- Fresh reviewers receive neutral context only (see Neutral Context Rule below).
- Do not write Parallax state into the target repo; use chat or `mktemp -d` temp dirs and clean them before returning.

---

## Stage 1 — Plan (orchestrator)

Always `claude-orch`. Produce a detailed implementation plan **and** a precise per-task coding spec for each unit of work (`prompts/coding-spec-template.md`). The plan is the linchpin: a writer engine at modest reasoning only succeeds if each spec nails what to build, exact interfaces, files to touch / not touch, constraints, and acceptance checks. Break work into the smallest independent tasks so Stage 3 can parallelize.

## Stage 2 — Plan-review (Plan-review engine, read-only)

Hand the plan to a **fresh** Plan-review engine to stress-test it *before any code exists*. Follow the **Neutral Context Rule**. Use the correctness brief (`prompts/correctness.md`) against the *plan*: wrong approach, missing edge cases, simpler alternative, unstated assumptions, gaps that would block the coder. Invoke per `lib/engines.md`. Reconcile findings with your own judgment — do not rubber-stamp. **Spend a revise turn only when it returns a Critical/High** (or you agree a material gap exists); otherwise fold any minor notes into the specs and proceed straight to Stage 3.

## Stage 3 — Code (Code engine, write)

Delegate each coding task to the Code engine, feeding it the per-task spec. The Code engine is whichever engine `parallax.yaml` assigns to `code` for the selected mode (default Claude), spawned as a named subagent: `plx:claude-worker` (fresh write-capable Claude), the orchestrator editing directly (quick/team), or — when configured — `plx:codex-worker` / `plx:grok-worker` running `codex-rw.sh` / `grok-rw.sh`. A fresh worker keeps the orchestrator's context lean and the first pass uncontaminated. Independent tasks run in parallel (one per task); dependent tasks run in order, passing prior outputs forward. Invoke per `lib/engines.md`. For risky changes, run in a disposable `git worktree` and review the diff before merging.

## Stage 4 — Refine

Improve the freshly-written code per `prompts/refine.md` (delete-before-simplify, de-slop, optimize, align to repo conventions), scoped to the new code. **Two shapes — the selected mode declares which:**

- **Direct** — an editor engine (e.g. `claude-orch`) reads the code and applies the improvements itself.
- **Delegated** — read-only **advisor** engines produce refine findings using the refine criteria; the **orchestrator** synthesizes one refine plan; the **applier** engine (the writer) executes it. Advisors never edit; only the applier writes.

Either shape ends with the **Structural Verdict** self-check (`prompts/refine.md`) — stated by whoever finishes refine (the editor, or the orchestrator before delegating apply). Record it (`none` if clean). Some pipelines also use refine as a read-only review/advisory lane; the skill's "## Pipeline" section declares that topology.

## Stage 5 — Review (read-only, parallel, neutral context)

Spawn fresh reviewers that never saw the code being written, each with only neutral context + its lane brief. They return findings only; they do not edit.

- **Debug** — the Debug engine(s) selected by the mode, brief `prompts/debug.md`. Robustness is folded in; security is surface-only.
- **Correctness** — the Correctness engine(s) selected by the mode, brief `prompts/correctness.md`: does the implementation solve the right problem per the spec?
- **Refine advisory** — only when selected by the mode, brief `prompts/refine.md`.

**Launch reviewers in a single orchestrator turn when the selected mode has multiple independent lanes** — spawn each lane's engine-named reviewer subagent (`plx:<engine>-reviewer`) in that same turn; then collect all results. Invoke CLI engines per `lib/engines.md`. Wait for all. All reviewers use the Lane Brief Template + Finding Schema in `prompts/synthesis.md`.

## Stage 6 — Fix

Synthesize the reports into one coherent pass following the **Ordered Synthesis** in `prompts/synthesis.md` (merge + dedupe debug reports, verify claims, correctness-first, then debug fixes on surviving code). **Two shapes — your roster declares which:**

- **Direct** — the editor engine (`claude-orch`) applies the fixes itself, in one coherent pass.
- **Delegated** — the orchestrator writes a fix plan; the applier engine (the writer) executes all edits.

Re-run the narrowest existing tests / typecheck / lint the repo already provides — via the repo's venv binaries (`.venv/bin/ruff`, `.venv/bin/pytest`, …), never `uv run` in a sandbox (see `lib/engines.md` → Verification). Report accepted vs rejected findings, severity-ranked.

---

## Neutral Context Rule (Stages 2 & 5)

When handing work to a fresh reviewer / advisor, pass **only**: the artifact under review (the plan, or the code/diff), the user's original task/spec verbatim, the lane brief, and relevant repo-guidance pointers (`AGENTS.md`, `CLAUDE.md`, conventions docs). Do **not** pass your own analysis, conclusions, justifications, prior-turn summaries, or any steer toward a verdict. Reviewers must re-derive judgment from the artifacts — this holds for the Claude subagents too (they're fresh, not the orchestrator).

## Output

Return a final summary: **Built** · **Plan changes** (Stage 2) · **Refine changes** + Structural Verdict (`none` if clean) · **Review findings** (debug + correctness, accepted vs rejected, severity-ranked) · **Fixes applied** · **Verification** (checks run and results) · **Residual risk**.

## Stop rules

Stop and ask if: the task is too small to justify the selected mode; the plan cannot be made precise enough for the Code engine; a required engine CLI is unavailable after `scripts/preflight.sh`; or the user wants a plan only (use Stage 1 alone).

## Non-goals

- Not for trivial or one-line changes.
- Not a security-review skill (surface obvious issues, recommend a dedicated pass).
- Not a research or planning-only skill — this builds and ships code.
