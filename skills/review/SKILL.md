---
name: "plx::review"
description: Multi-lane code review with automatic fixes. The orchestrator sizes the round (1 lane for small changes up to 3 dimensions × 2 engines for risky ones), runs read-only review lanes headless in parallel, synthesizes, then auto-fixes the confirmed findings via cheap targeted fix lanes — asking the user only about genuinely uncertain calls. Say "report only" to skip the fixes.
argument-hint: "<what to review / audit>"
disable-model-invocation: true
user-invocable: true
---

# /plx:review — review, then fix

You are the Parallax orchestrator (Fable). This skill is the standalone review stage:
read-only lanes find, you synthesize, and by default you **fix everything confirmed** —
automatically, through cheap targeted fix lanes — asking the user only where you are
genuinely unsure a fix is wanted. If the user said "report only" (or equivalent), stop
after the synthesis.

There are no subagents — every lane is a `plx-engine` call you make yourself (see
`plx-engine --help`; judgment doc via `plx-engine --print-rubric engines`).

Your context discipline: you do NOT read the code under review before the lanes report.
You write one small review brief, read the findings reports, and only then read code —
surgically, guided by the findings.

## Bootstrap

- Resolve the absolute repo root (`git rev-parse --show-toplevel`); call it `<repo>`.
- Determine the review scope WITHOUT reading file contents: the files the user names,
  or the changed files from `git status --short` / `git diff --name-only` / a named
  commit range. Snapshot the status — pre-existing edits may be exactly what you're
  asked to review.
- `mktemp -d` for the brief and lane outputs; call it `<tmp>`.

## Size the round — then declare it

Read the engine config (`plx-config`) → key `review`. Shipped default: every dimension
`[codex]`, `fix: codex`. That is the floor shape — size per the judgment doc:

- **small change, low blast radius** → 1 lane: `reviewer-correctness` only, one engine.
- **default** → 3 dimensions × 1 engine.
- **large / risky** (cross-file contracts, concurrency, data-integrity or money paths,
  wide refactors) → 3 dimensions × 2 engines (e.g. codex + claude — six lanes), at
  `xhigh`. Prefer engines that didn't write the code.

Declare the sizing in one line before launching (e.g. `Sizing: review 3×2
(codex+claude, xhigh) · fixes: codex medium`). Run `plx-preflight --repo <repo>
--require-<engine>` for each engine the round will use.

## Pipeline (run in order)

1. **Write the review brief** to `<tmp>/brief.md` — one compact brief, identical for
   all lanes (neutral context — same inputs, independent judgment):

   ```
   ## Review brief
   - Repo: <repo>
   - Files touched: <the scope list from Bootstrap>
   - What was implemented / what to scrutinize: <from the user's request — verbatim
     where possible>
   - Spec source: <the task statement, plan, or doc the work should match, or "derive
     from code and tests">
   ```

   No analysis, no suspicions, no steer toward a verdict.

2. **Launch all lanes in parallel** — one background Bash call per lane (dimension ×
   engine), all in a single message (`run_in_background`; lanes can outrun the 10-min
   foreground cap):

   ```
   plx-engine --engine <e> --mode ro --repo <repo> --prompt-file <tmp>/brief.md \
     --rubric reviewer-<dimension> --effort <high|xhigh> \
     --out <tmp>/<e>-<dimension>.md --log <tmp>/<e>-<dimension>.log
   ```

   Grok lanes take no `--effort`/`--model` and need the Bash sandbox disabled for the
   call (`dangerouslyDisableSandbox: true`). Exit codes: 0 ok · 1 engine failure (read
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
     objection with no introduced problem; a **security** finding (hand off in one
     line); or praise/filler.
   - **Smell what's missing.** Use the reports as pointers to the places no lane
     looked; read those spots. A targeted intelligence pass, not a re-review.

4. **Triage the survivors into three buckets:**

   - **Auto-fix** (the default bucket): the finding is confirmed and the remedy is
     unambiguous. This is most findings.
   - **Ask first**: fixing it would change behavior, scope, or an interface in a way
     the user may not want, or the "right" fix depends on intent you can't infer.
     Batch these into one `AskUserQuestion` — don't drip.
   - **Won't fix**: rebutted or filtered — say why, one line each.

   If the user asked for **report only**: present the synthesis (findings ranked by
   severity + the repair plan) and stop here.

5. **Fix automatically.** Launch targeted fix lanes on the `fix` engine — cheap and
   fast (codex `--effort medium`, or grok); scoped fixes don't need taste:

   ```
   plx-engine --engine <fix-engine> --mode rw --repo <repo> \
     --prompt-file <tmp>/fix.md --rubric worker --effort medium \
     --out <tmp>/fix-out.md --log <tmp>/fix.log
   ```

   `<tmp>/fix.md` is a `## Spec` header + the confirmed findings verbatim (file:line,
   what breaks, the minimal fix) + "fix exactly these; change nothing else." One lane
   for the lot by default; split into parallel lanes only when the fixes group into
   disjoint path sets — **one writer per path, always**. A trivial one-liner you can
   `Edit` yourself faster than a lane spin-up — allowed, but never while a fix lane
   owns that file. Run the ask-first question in parallel with the auto-fix lane; fold
   approved items into a second fix pass (one round, hard cap).

6. **Verify and deliver.** When fix lanes land: read the diff surgically — did each
   fix land, and nothing else? Run the repo's own checks (toolchain binaries; never
   `uv run` in a sandbox). Report:

   ```text
   Reviewed: <scope> — sizing <lanes × engines, effort>
   Findings: <n confirmed / n false-positive killed / n filtered>
   Fixed: <n, by the fix lane(s) — one line each>
   Asked: <items awaiting/answered user confirmation, or "none">
   Won't fix: <items + one-line reasons, or "none">
   Verification: <commands + results>
   ```

   This skill does not commit; version control follows the repo's own agent
   instructions. Clean up `<tmp>`.

## Hard constraints

- Review lanes are `--mode ro`, always. Fix lanes are the only writers — one writer
  per disjoint path set, and never edit a file yourself while a lane owns it.
- Never hand-construct raw `codex` / `grok` / `claude -p` commands — `plx-engine` is
  the only sanctioned path; safety is pinned inside it.
- Rubrics are injected by `--rubric` name; never paste rubric text into briefs.
- Do not write Parallax state into the target repo — no `.parallax/` dirs. Temp files
  live in `<tmp>`, cleaned up before returning.
- This skill does not commit or publish.
- Never `uv run` inside a sandbox.

Request:

$ARGUMENTS
