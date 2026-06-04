# Parallax pipeline (role-based)

Shared role definitions and neutral-context rules for LLX modes. This file is not the executable workflow authority — `skills/llx/modes.md` owns exact mode steps, and `references/engines.md` holds how to invoke each engine.

**Roles:** Plan · Plan-review · Code · Refine · Debug review · Correctness review · Fix. Plan, plan/spec synthesis, and review/fix synthesis are always the orchestrator (`claude-orch`).

Work artifacts (prompts, engine outputs, findings) go in the absolute run directory created by Parallax intake. Add `.parallax/` to `.gitignore`.

| # | Stage | Role | Edits repo? |
|---|---|---|---|
| 1 | Plan | orchestrator | no |
| 2 | Plan-review | Plan-review engine (read-only) | no |
| 3 | Code | Code engine (write) | **yes** |
| 4 | Refine | Refine role (direct *or* delegated) | **yes** |
| 5 | Review | Debug engine(s) + Correctness engine (read-only) | no |
| 6 | Fix | Fix role (direct *or* delegated) | **yes** |

---

## Stage 1 — Plan (orchestrator)

Always `claude-orch`. Produce a detailed implementation plan **and** a precise per-task coding spec for each unit of work (`references/coding-spec-template.md`). The plan is the linchpin: a writer engine at modest reasoning only succeeds if each spec nails what to build, exact interfaces, files to touch / not touch, constraints, and acceptance checks. Break work into the smallest independent tasks so Stage 3 can parallelize.

## Stage 2 — Plan-review (Plan-review engine, read-only)

Hand the plan to a **fresh** Plan-review engine to stress-test it *before any code exists*. Follow the **Neutral Context Rule**. Use the correctness brief (`references/correctness.md`) against the *plan*: wrong approach, missing edge cases, simpler alternative, unstated assumptions, gaps that would block the coder. Invoke per `references/engines.md`. Reconcile findings with your own judgment — do not rubber-stamp. **Spend a revise turn only when it returns a Critical/High** (or you agree a material gap exists); otherwise fold any minor notes into the specs and proceed straight to Stage 3.

## Stage 3 — Code (Code engine, write)

Delegate each coding task to the Code engine, feeding it the per-task spec. The Code engine is a fresh write-capable Claude worker (`worker`) or — for quick mode — the orchestrator editing directly. A fresh worker keeps the orchestrator's context lean and the first pass uncontaminated. Independent tasks run in parallel (one per task); dependent tasks run in order, passing prior outputs forward. Invoke per `references/engines.md`. For risky changes, run in a disposable `git worktree` and review the diff before merging.

## Stage 4 — Refine

Improve the freshly-written code per `references/refine-guide.md` (delete-before-simplify, de-slop, optimize, align to repo conventions), scoped to the new code. **Two shapes — the selected mode declares which:**

- **Direct** — an editor engine (e.g. `claude-orch`) reads the code and applies the improvements itself.
- **Delegated** — read-only **advisor** engines produce refine findings using the refine criteria; the **orchestrator** synthesizes one refine plan; the **applier** engine (the writer) executes it. Advisors never edit; only the applier writes.

Either shape ends with the **Structural Verdict** self-check (`references/refine-guide.md`) — stated by whoever finishes refine (the editor, or the orchestrator before delegating apply). Record it (`none` if clean). Some modes also use refine as a read-only review/advisory lane; `modes.md` is authoritative for that topology.

## Stage 5 — Review (read-only, parallel, neutral context)

Spawn fresh reviewers that never saw the code being written, each with only neutral context + its lane brief. They return findings only; they do not edit.

- **Debug** — the Debug engine(s) selected by the mode, brief `references/debug.md`. Robustness is folded in; security is surface-only.
- **Correctness** — the Correctness engine(s) selected by the mode, brief `references/correctness.md`: does the implementation solve the right problem per the spec?
- **Refine advisory** — only when selected by the mode, brief `references/refine-guide.md`.

**Launch reviewers in a single orchestrator turn when the selected mode has multiple independent lanes** — background the CLI calls and spawn Claude reviewer subagents in that same turn; then collect all results. Invoke CLI engines per `references/engines.md`. Wait for all. All reviewers use the Lane Brief Template + Finding Schema in `references/review-briefs.md`.

## Stage 6 — Fix

Synthesize the reports into one coherent pass following the **Ordered Synthesis** in `references/review-briefs.md` (merge + dedupe debug reports, verify claims, correctness-first, then debug fixes on surviving code). **Two shapes — your roster declares which:**

- **Direct** — the editor engine (`claude-orch`) applies the fixes itself, in one coherent pass.
- **Delegated** — the orchestrator writes a fix plan; the applier engine (the writer) executes all edits.

Re-run the narrowest existing tests / typecheck / lint the repo already provides — via the repo's venv binaries (`.venv/bin/ruff`, `.venv/bin/pytest`, …), never `uv run` in a sandbox (see `references/engines.md` → Verification). Report accepted vs rejected findings, severity-ranked.

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
