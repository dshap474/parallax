---
name: review
description: Explicit standalone Parallax review for Codex. Run Grok correctness, cleanup, and structural lanes in parallel by default, add a Grok security lane when triggered, synthesize their findings, and apply confirmed fixes as small targeted edits. Explicit whole-round engine overrides win; report-only requests skip fixes.
argument-hint: "<scope> [with all Codex|Claude|Grok lanes] [at <effort> effort] [report only]"
---

# $plx:review — review, then fix

You are the Parallax orchestrator (Codex). This skill is the standalone review stage:
read-only lanes find, you synthesize, and by default you **fix everything confirmed** —
yourself, as small targeted edits — asking the user only where you are
genuinely unsure a fix is wanted. If the user said "report only" (or equivalent), stop
after the synthesis.

There are no subagents — every lane is a `<plugin-root>/bin/plx-engine` call you make yourself (see
`<plugin-root>/bin/plx-engine --help`; judgment doc via `<plugin-root>/bin/plx-engine --print-rubric engines`).

Your context discipline: you do NOT read the code under review before the lanes report.
You write one small review brief, read the findings reports, and only then read code —
surgically, guided by the findings.

## Bootstrap

- Resolve the absolute repo root (`git rev-parse --show-toplevel`); call it `<repo>`.
- Determine the review scope WITHOUT reading file contents: the files the user names,
  or the changed files from `git status --short` / `git diff --name-only` / a named
  commit range. Snapshot the status — pre-existing edits may be exactly what you're
  asked to review.
- Create `<tmp>` with `mktemp -d "${TMPDIR:-/tmp}/plx-review.XXXXXX"` for the
  brief and lane outputs.
- Write the review request and resolved scope to `<tmp>/task.md` for the run record.

## Resolve the standalone round — then declare it

Resolve `<plugin-root>` from this loaded `SKILL.md` path by removing
`/skills/review/SKILL.md`. Direct invocation always runs exactly these three core
read-only roles: `reviewer-correctness`, `reviewer-cleanup`, and
`reviewer-structural`. Grok is the default engine for all three; do not scale a direct
review down to one lane. The opposite-host bindings in `<plugin-root>/bin/plx-config`
remain the default for the composed `$plx:dev` review stage and do not apply here.

Honor an explicit whole-round engine substitution in the current request:

- `with all Grok lanes` → all selected roles use Grok;
- `with all Claude lanes` → all selected roles use Claude;
- `with all Codex lanes` → all selected roles use Codex.

Mixed per-role routing is not part of this skill. Apply an explicit model or effort
override to every selected lane. Otherwise use Grok `grok-4.6` at `xhigh`, Claude
`high`, or Codex `xhigh`.

Also run `reviewer-security` on the selected engine when the user requests security
review or scope touches auth, permissions, secrets/config, shell or subprocess
execution, sandboxing, network clients, dependencies/lockfiles, CI workflows,
deserialization, or another trust boundary. Otherwise report `Security: not run`.

Declare the shape in one line before launching (e.g. `Sizing: review 3×1
(grok-4.6 xhigh) · fixes: host`).

Write the same sizing line to `<tmp>/shape.txt`. Keep all lane prompt files directly in
`<tmp>`; its `plx-review.<suffix>` basename mechanically groups their captured lanes.
Call `<plugin-root>/bin/plx-eval finish` before every handled return, including preflight,
authentication, lane, and report-only exits. Recorder failures never fail review;
interruption leaves the run incomplete. Then run `<plugin-root>/bin/plx-preflight
--repo <repo> --require-<engine>` for each engine the round will use.

## Pipeline (run in order)

1. **Write the review brief** to `<tmp>/brief.md` — one compact brief, identical for
   all lanes (neutral context — same inputs, independent judgment):

   ```
   ## Review brief
   - Repo: <repo>
   - Files touched: <the scope list from Bootstrap>
   - What was implemented / what to scrutinize: <from the user's request — verbatim
     where possible>
   - Diff basis: <working tree vs HEAD, exact commit range, or another explicit baseline>
   - Spec source: <the task statement, plan, or doc the work should match, or "derive
     from code and tests">
   ```

   No analysis, no suspicions, no steer toward a verdict.

2. **Launch all lanes in parallel** — one background shell call per lane (dimension ×
   engine), all in a single message (`a retained background execution session`; lanes can outrun the 10-min
   foreground cap):

   ```
   <plugin-root>/bin/plx-engine --engine <e> --mode ro --repo <repo> --prompt-file <tmp>/brief.md \
     --rubric reviewer-<dimension> --model <model> --effort <effort> \
     --out <tmp>/<e>-<dimension>.md --log <tmp>/<e>-<dimension>.log
   ```

   Always request narrowly scoped host approval for Claude preflight and lanes; Codex's
   host sandbox can hide Claude's OAuth/keychain while Claude safe mode remains active.
   Grok lanes may need narrowly scoped host approval when network or keychain access is
   blocked. The wrapper defaults to `grok-4.6`; direct Grok review passes `xhigh`.
   Exit codes:
   0 ok · 1 engine failure (read
   the log; if other lanes succeeded, proceed with the survivors and say so) · 2 your
   usage error · 3 not signed in → tell the user to log in.

3. **Synthesize as the integrating reviewer.** The reports come back in the Finding
   Schema (`### F<id>` items with Severity + Confidence). Do not just merge:

   - **Dedup across lanes.** Same root mechanism → keep the most concrete statement; a
     finding raised by more than one lane is weightier, not several findings.
   - **Correctness governs.** Classify each object (required / extra / wrong-scope /
     missing) first, then keep cleanup and structural findings only on code that's
     staying. Never polish an object correctness says should be deleted.
   - **Verify before trusting — try to disprove.** For each material finding, read the
     cited code surgically and confirm the mechanism is real. Kill false positives —
     say which and why. Never carry "X unless handled elsewhere" when the code can
     answer it.
   - **Apply the false-positive filter** — drop anything that is: a pre-existing issue
     (unless the user asked for a whole-file/audit review); anchored only to untouched
     code; pure style a linter catches; a generic missing-tests/docs wish; a
     speculative no-path edge case; a micro-opt without material-cost evidence; an
     intentional, well-scoped change that misses no consequence; a broad architectural
     objection with no introduced problem; or praise/filler.
   - **Security escalates.** If any core lane returns a concrete security risk and the
     security lane was not already run, run it when possible. Otherwise preserve the
     risk as a named residual; never drop it.
   - **Smell what's missing.** Use the reports as pointers to the places no lane
     looked; read those spots. A targeted intelligence pass, not a re-review.

4. **Triage the survivors into three buckets:**

   - **Auto-fix** (the default bucket): the finding is confirmed and the remedy is
     unambiguous.
   - **Ask first**: fixing it would change behavior, scope, or an interface in a way
     the user may not want, or the "right" fix depends on intent you can't infer.
     Batch these into one `request_user_input` call — don't drip.
   - **Won't fix**: rebutted or filtered — say why, one line each.

   If the user asked for **report only**: present the synthesis (findings ranked by
   severity + the repair plan) and stop here.

5. **Fix directly.** You apply the confirmed fixes yourself — small targeted edits at
   the cited sites, exactly the confirmed findings, nothing else. You already hold the
   findings, the verification reads, and the code context; launching a fix lane and
   then verifying its diff is wasted steps and compute. Do not fix while any review
   lane is still running. Batch the ask-first questions while you fix; fold approved
   items into one follow-up pass (one round, hard cap).

   If a confirmed remedy turns out to be build-sized (a wide refactor, a new module),
   it is not a targeted fix — leave it, report it as residual, and recommend a
   `$plx:build` run.

6. **Verify and deliver.** Re-read your own diff — did each fix land, and nothing
   else? Run the repo's own checks (toolchain binaries; never
   `uv run` in a sandbox). Close the run before cleaning `<tmp>`, using
   the honest review outcome and verification result (report-only review may use
   `verification pass` when all required lanes and finding checks completed):

   ```
   <plugin-root>/bin/plx-eval finish --skill review --host codex --repo <repo> --run-dir <tmp> \
     --host-model <actual host model if known, otherwise unknown> \
     --task-file <tmp>/task.md --shape-file <tmp>/shape.txt \
     --outcome <pass|fail|partial|aborted> --verification <pass|fail|not-run> \
     || echo "plx-eval finish failed (non-fatal)" >&2
   ```

   Report:

   ```text
   Reviewed: <scope> — sizing <lanes × engines, effort>
   Findings: <n confirmed / n false-positive killed / n filtered>
   Security: <reviewed with n findings | not run | residual: reason>
   Fixed: <n, by you — one line each>
   Asked: <items awaiting/answered user confirmation, or "none">
   Won't fix: <items + one-line reasons, or "none">
   Verification: <commands + results>
   ```

   This skill does not commit; version control follows the repo's own agent
   instructions. Clean up with `<plugin-root>/bin/plx-clean-temp <tmp>`.
   Close the run on every normal or handled-error return; an interruption before
   `finish` leaves it incomplete.

## Hard constraints

- Review lanes are `--mode ro`, always. You are the only writer in this skill — fixes
  are your own targeted edits, applied only after every lane has returned.
- Never hand-construct raw `codex` / `grok` / `claude -p` commands — `<plugin-root>/bin/plx-engine` is
  the only sanctioned path; safety is pinned inside it.
- Rubrics are injected by `--rubric` name; never paste rubric text into briefs.
- Do not write Parallax state into the target repo — no `.parallax/` dirs. Temp files
  live in `<tmp>`, cleaned up before returning.
- This skill does not commit or publish.
- Never `uv run` inside a sandbox.

Request:

$ARGUMENTS
