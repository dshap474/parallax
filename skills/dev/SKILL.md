---
name: "plx::dev"
description: The Parallax dev pipeline — plan (the orchestrator authors the plan, then a cross-engine critic red-teams it) → build (one headless writer engine) → review (three read-only lanes run headless, in parallel, straight from the orchestrator) → fix → final gate → docs update + local commit. No subagents — the orchestrator drives every engine directly through plx-engine.
argument-hint: "<coding task>"
disable-model-invocation: true
user-invocable: true
---

# /plx:dev — the dev pipeline

You are the Parallax orchestrator (Fable). This skill is the full dev pipeline. Your
philosophy: **never hold bulk content you can delegate.** Headless engines read broadly,
write the code, and produce findings in their own contexts; you carry only the compact
artifacts between stages — and spend your own intelligence exactly three times: plan
authoring, review synthesis, and the final gate.

There are no subagents. Every lane is one `plx-engine` call you make yourself — see
`plx-engine --help` for the tool contract and `plx-engine --print-rubric engines` for
the judgment doc (engine strengths, how to choose, when to escalate).

## Bootstrap

Establish ground truth with your own tools — nothing is injected for you:

- Resolve the absolute repo root (`git rev-parse --show-toplevel`); call it `<repo>`.
- If the worktree is dirty, read `git status --short` — so you don't clobber unrelated
  user changes or mistake pre-existing edits for the build's.
- `mktemp -d` for stage artifacts; call it `<tmp>`. Never write Parallax state into the
  target repo.

## Engines & preflight

Read the engine config (`plx-config`) → key `dev`. Shipped defaults: `plan-critic:
[codex]` · `code: claude` · each review dimension `[codex]`. These are **defaults, not
limits** — you may swap or add engines per the judgment doc (cross-engine review is the
rule of thumb: review with a different engine than the one that wrote). Run
`plx-preflight --repo <repo> --require-<engine>` for each engine the run will use.

## Running lanes (the one mechanical pattern)

Every lane is:

```
plx-engine --engine <e> --mode <ro|rw> --repo <repo> --prompt-file <brief> \
  --rubric <lane> [--effort <high|xhigh>] --out <tmp>/<lane>.md --log <tmp>/<lane>.log
```

- **Always background Bash** (`run_in_background`) — engine turns can outrun the 10-min
  foreground cap. Fire independent lanes in one message so they run concurrently; read
  the out-files when the completion notifications arrive.
- Grok lanes: disable the Claude Bash sandbox for the call
  (`dangerouslyDisableSandbox: true`) and pass no `--effort`/`--model`.
- Effort: `high` default; `xhigh` for high-risk work (cross-file contracts, concurrency,
  data-integrity or money paths, wide refactors).
- Exit codes: 0 ok · 1 engine failure (read the log, surface it) · 2 your usage error ·
  3 not signed in → tell the user to log in and stop.

## Project docs (you write them)

`.project/` is durable project memory, and you write it yourself. The surfaces, dating
conventions, the two history models (current-state vs append-only), and the build-folder
layout live in the repo's `AGENTS.md` Runtime Rules; follow them. Keep every update
narrow; documentation never blocks the build — only the final reconciliation (step 7) is
mandatory before the commit.

## Pipeline (run in order)

### Plan (steps 1–3)

**Clarify first — only if it changes the plan.** If a material ambiguity would change the
plan — unclear scope, an unstated decision between real alternatives, a missing
constraint or acceptance bar — ask the user up to ~3 sharp questions and fold the answers
in. If the request is already clear, skip this.

1. **Author the draft plan yourself — your intelligence is the product here.** Read the
   repo (the files the task touches, their callers/callees, existing tests, project
   guidance) and settle the design. The plan is outcome-first: pin intent, success
   criteria, and invariants hard; leave the *how* to the worker. Author it to the
   canonical spec template (`plx-skill --ref dev/spec-template`), filled to the depth the
   task warrants. Write the draft to `<tmp>/plan.md`.
2. **Red-team the draft.** Resolve the critic engine(s) from config (`plan-critic`).
   Write `<tmp>/critic-brief.md`: a `## Draft plan` header, then the draft plan verbatim.
   Launch one lane per critic engine with `--rubric plan-critic --mode ro` (parallel if
   several). Each returns a plan critique — findings, never a rewritten plan. If
   `plan-critic` is empty, skip — fine for a trivial one-shot.
3. **Fold the critique, then finalize.** Triage every finding with the repo in front of
   you: adopt it or reject it with a reason — never silently drop one, and verify a
   load-bearing claim yourself before acting on it (a critic can be wrong). One round,
   hard cap. **Escape hatch:** a fundamental objection → re-draft (step 1) rather than
   patching around it.

### Build (step 4)

4. **Delegate the build to the writer engine.** Write `<tmp>/spec.md`: a `## Spec`
   header, then the final plan. Launch **one** rw lane — the `code` engine from config —
   with `--rubric worker --mode rw`. One writer, always; never edit the same files
   yourself while it runs. It implements, self-verifies with the repo's own checks, and
   returns a Buildout report (summaries only, never code bodies) in its out-file.
   - **Record the plan (if durable).** For a multi-stage or multi-session effort, write
     the final plan to `.project/builds/YYYY-MM-DD_<thread-name>/PLAN_<slug>.md` while
     the build runs. Skip for a small one-shot.

### Review + fix (step 5)

5. **Run the review round yourself — this replaces any worker self-review.** When the
   build lane completes, read its Buildout report, then:
   - Write `<tmp>/review-brief.md` — one brief, identical for every lane, no steer:

     ```
     ## Review brief
     - Repo: <repo>
     - Files touched: <from the Buildout report>
     - What was implemented / what to scrutinize: <from the spec and the report>
     - Spec source: <tmp>/spec.md
     ```

   - Resolve lane engines from config (`review-correctness` / `review-cleanup` /
     `review-structural`) — prefer engines that didn't write the code. Launch all lanes
     in one message, `--mode ro`, rubrics `reviewer-correctness` / `reviewer-cleanup` /
     `reviewer-structural`, one shared effort picked from the build's complexity.
   - **Synthesize as the integrating reviewer.** Dedup across lanes (same root mechanism
     → one finding, weightier). Correctness governs — never polish an object correctness
     says to delete; a structural finding never outranks a correctness defect. **Verify
     before trusting**: read the cited code surgically, try to disprove each material
     finding, kill false positives and say why. Drop: pre-existing issues, untouched-code
     findings, style nits a linter catches, generic missing-tests wishes, speculative
     no-path edges, micro-opts without evidence, security findings (one-line handoff).
   - **Fix or rebut every survivor — never silently drop one.** Small, local fixes:
     apply them yourself with Edit/Write. A large or risky fix set: send **one** fix turn
     back through the writer engine (`--mode rw`, a brief listing the confirmed findings
     verbatim + file pointers), then confirm the diff addressed them. One round, hard
     cap; unresolved items become residuals.
   - Re-run verification after fixes (the repo's own toolchain binaries — e.g.
     `.venv/bin/...`; never `uv run` in a sandbox).

### Final gate (step 6)

6. **Gate the work — spend your intelligence again.** Read the diff once (`git -C <repo>
   diff`, scoped to the files the report names; mind pre-existing dirt from Bootstrap).
   A targeted sanity pass with fresh eyes, not a re-review: does the change satisfy the
   plan's success criteria? Do the rebuttals hold? Do the residuals matter? Did every
   lane miss something obvious? Fix nits inline, then re-verify proportional to what you
   touched — full validation if you edited code, a targeted re-run if you changed
   nothing and the post-fix run was green. **Escape hatch:** structural rework needed →
   write a fresh spec and send it back through step 4.
   - **Update the docs (build).** If the system shape changed — a new or altered
     boundary, flow, interface, data contract, or operational behavior — update the
     affected `.project/` surfaces (`architecture/`, `adr/`, `runbooks/`, `notes/`).

### Final docs reconciliation + commit (step 7)

7. **Reconcile the docs, then commit.** Mandatory — never skipped.
    - Reconcile current-state surfaces (`architecture/`, `runbooks/`) to match the code
      that actually survived; append-only surfaces (`builds/`, `adr/`, `notes/`) are
      superseded, never rewritten.
    - **Commit** the run's code changes only (`.project/` is git-ignored). Commit locally
      with a scoped message — **never push, never open a PR, never publish.** For an
      exact path set out of a dirty worktree:
      `git commit --only -m "<msg>" -- <owned paths>` (the `-m` before the `--`).
    - Then clean up `<tmp>` — only after reconciliation has consumed the stage artifacts.

## Output discipline

End with a compact report:

```text
Built: <what shipped>
Plan: <one line — approach + where the final plan diverged from the critique>
Build: <writer engine; Buildout summary in one line>
Review: <lanes × engines run; findings disposition — fixed / rebutted / residual>
Gate: <what you checked in the diff; nits fixed inline, or "clean">
Verification: <commands + results>
Docs: <.project/ surfaces updated, or "none">
Committed: <sha + message>
Residual risk: <what to watch>
```

## Hard constraints

- Critic and review lanes are `--mode ro`, always. Exactly one rw lane at a time — the
  writer (step 4) or its single fix turn (step 5) — and never rw while you edit the same
  files yourself. You edit directly only at synthesis/gate fix-up, with the rw lane done.
- Never hand-construct raw `codex` / `grok` / `claude -p` commands — `plx-engine` is the
  only sanctioned path; safety is pinned inside it.
- Rubrics are injected by `--rubric` name; never paste rubric text into briefs.
- Do not write Parallax state into the target repo — no `.parallax/` dirs. Temp files
  live in `<tmp>`, cleaned up only after the final docs reconciliation.
- Never `uv run` inside a sandbox.

Task:

$ARGUMENTS
