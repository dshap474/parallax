---
name: "plx::review"
description: Multi-lane code review. Three read-only review lanes — correctness, cleanup, structural — run headless in parallel straight from the orchestrator (no subagents), then the orchestrator synthesizes as the integrating reviewer. Read-only; does not modify files unless you explicitly ask for fixes.
argument-hint: "<what to review / audit>"
disable-model-invocation: true
user-invocable: true
---

# /plx:review — multi-lane review

You are the Parallax orchestrator (Fable). This skill is the standalone review pipeline —
you drive every lane directly through `plx-engine` (see `plx-engine --help`; judgment doc
via `plx-engine --print-rubric engines`). Three dimension lanes review in parallel —
**correctness**, **cleanup**, **structural** — and you synthesize as the integrating
reviewer. **Do not edit files** unless the user explicitly asked for fixes.

Your context discipline: you do NOT read the code under review before the lanes report.
You write one small review brief, read the findings reports, and only then read code —
surgically, guided by the findings.

## Bootstrap

Establish ground truth with your own tools — nothing is injected for you:

- Resolve the absolute repo root (`git rev-parse --show-toplevel`); call it `<repo>`.
- Determine the review scope WITHOUT reading file contents: the files the user names, or
  the changed files from `git status --short` / `git diff --name-only` / a named commit
  range. Pre-existing edits may be exactly what you're asked to review.
- `mktemp -d` for the brief and lane outputs; call it `<tmp>`.

## Engines & preflight

Read the engine config (`plx-config`) → key `review`. Shipped default: every dimension
`[codex]`. Defaults, not limits — add or swap engines per the judgment doc (e.g. a second
engine on a high-risk change buys independent perspective; if you know who wrote the
code, prefer a different engine). Run `plx-preflight --repo <repo> --require-<engine>`
for each engine the round will use.

## Pipeline (run in order)

1. **Write the review brief** to `<tmp>/brief.md` — one compact brief, identical for all
   lanes (neutral context — same inputs, independent judgment):

   ```
   ## Review brief
   - Repo: <repo>
   - Files touched: <the scope list from Bootstrap>
   - What was implemented / what to scrutinize: <from the user's request — verbatim
     where possible>
   - Spec source: <the task statement, plan, or doc the work should match, or "derive
     from code and tests">
   ```

   No analysis, no suspicions, no steer toward a verdict. The lanes re-derive judgment
   from the repo themselves.

2. **Launch all lanes in parallel** — one background Bash call per lane (dimension ×
   engine), all in a single message:

   ```
   plx-engine --engine <e> --mode ro --repo <repo> --prompt-file <tmp>/brief.md \
     --rubric reviewer-<dimension> --effort <high|xhigh> \
     --out <tmp>/<e>-<dimension>.md --log <tmp>/<e>-<dimension>.log
   ```

   - Rubrics: `reviewer-correctness` (spec match + behavioral defects),
     `reviewer-cleanup` (reuse, simplification, efficiency, altitude),
     `reviewer-structural` (maximalist maintainability). All three dimensions run, every
     time — none is opt-in.
   - One shared effort from the change's complexity: `high` default; `xhigh` only for
     high-risk changes (cross-file contracts, concurrency, data-integrity or money
     paths, wide refactors). Grok lanes take no `--effort` and need the Bash sandbox
     disabled for the call (`dangerouslyDisableSandbox: true`).
   - **Always background Bash** (`run_in_background`) — lanes can outrun the 10-min
     foreground cap. Read the out-files as completion notifications arrive.
   - Exit codes: 0 ok · 1 engine failure (read the log, surface it) · 2 your usage
     error · 3 not signed in → tell the user to log in.

3. **Synthesize as the integrating reviewer.** The reports come back in the Finding
   Schema (`### F<id>` items with Severity + Confidence). Do not just merge:

   - **Dedup across lanes.** Same root mechanism → keep the most concrete statement; a
     finding raised by more than one lane is weightier, not several findings.
   - **Correctness governs.** Its verdicts on scope and behavior decide what survives:
     classify each object (required / extra / wrong-scope / missing) first, then keep the
     cleanup and structural findings only on code that's staying. Never polish or
     restructure an object correctness says should be deleted. A structural finding never
     outranks a correctness defect.
   - **Verify before trusting — try to disprove.** For each material finding, read the
     cited code surgically and confirm the mechanism is real. Kill false positives — say
     which and why. Never carry "X unless handled elsewhere" when the code can answer it.
   - **Apply the false-positive filter** — drop anything that is: a pre-existing issue;
     anchored only to untouched code; pure style/formatting a linter/formatter/CI catches;
     a generic missing-tests/docs wish; a speculative no-path edge case; a micro-opt with
     no material-cost evidence; an intentional, well-scoped change that misses no
     consequence; a broad architectural objection with no introduced problem and
     proportionate remedy; a **security** finding (hand off in one line); or praise/filler.
   - **Smell what's missing.** Use the reports as pointers to what the lanes might have
     missed — adjacent code paths, an error pattern that suggests a deeper cause, the
     places no lane looked. Read those spots. Not a full re-review; a targeted
     intelligence pass.

   Rank survivors by **impact** (Severity), not confidence; within a severity, order by
   confidence and blast radius.

   Output: the **repair plan** — each item with location, what to change, why, and which
   findings it resolves (or "won't fix" with the reason).

4. **Deliver.** Report the synthesized findings and the repair plan, clean up `<tmp>`,
   then **stop** — review is read-only. Apply the repair plan only if the user explicitly
   asked for fixes (then verify with the repo's own toolchain and report what you ran).
   If the user wants the full loop, point at `/plx:dev`.

## Hard constraints

- Every lane is `--mode ro`, whatever engine fills it. Never route a review lane through
  rw.
- Never hand-construct raw `codex` / `grok` / `claude -p` commands — `plx-engine` is the
  only sanctioned path; safety is pinned inside it.
- Rubrics are injected by `--rubric` name; never paste rubric text into briefs.
- Do not write Parallax state into the target repo — no `.parallax/` dirs. Temp files
  live in `<tmp>`, cleaned up before returning.
- Never `uv run` inside a sandbox.

Request:

$ARGUMENTS
