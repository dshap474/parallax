---
name: "plx::build"
description: The Parallax build stage, standalone — one or more headless writer lanes (plx-engine, rw) implement a plan. Takes a spec doc path, a plan from this conversation, or a raw task. The orchestrator sizes the run — one worker by default, parallel file-disjoint workers for large separable work — verifies, and reports. No review round; run /plx:review after.
argument-hint: "<spec path, or the task — omit to build the plan from this conversation>"
disable-model-invocation: true
user-invocable: true
---

# /plx:build — delegate a build to writer lanes

You are the Parallax orchestrator (Fable). This skill turns a plan into a verified
implementation through headless writer lanes. Your context discipline: the writer reads
the repo and writes the code in its own context; you carry the spec out and the Buildout
report back.

There are no subagents. Every lane is one `plx-engine` call you make yourself — see
`plx-engine --help` for the tool contract and `plx-engine --print-rubric engines` for
the judgment doc (model rankings, sizing ladder, writer rules).

## Resolve the plan

The build input, in order of precedence:

1. **A spec doc path** in the arguments (e.g. from `/plx:plan` or `/plx:goal-spec`) —
   read it; that file is the spec.
2. **A plan already in this conversation** (from `/plx:plan` or discussion) — use it
   verbatim; don't re-plan.
3. **A raw task** — no plan exists. For a clear, bounded task, write a brief spec
   inline yourself (intent, success criteria, constraints) and proceed; for anything
   ambiguous or wide, tell the user to run `/plx:plan` first and stop.

Whatever the source, the spec must end with a **`Done means:` line** — the concrete
command(s) or observable(s) that prove the work. If the plan lacks one, add it yourself
before briefing the lane: it is what the worker self-verifies against, and what you
re-run at integration.

## Bootstrap

- Resolve the absolute repo root (`git rev-parse --show-toplevel`); call it `<repo>`.
- `mktemp -d` for briefs and lane outputs; call it `<tmp>`.
- Snapshot `git status --short` and the current staged/unstaged diff into `<tmp>` —
  pre-existing edits must be preserved and must not be attributed to this build.

## Size the run — then declare it

Read the engine config (`plx-config`) → key `build`. Shipped default: `code: grok` —
one Grok 4.5 writer at medium effort. Use Codex only as a reported fallback when Grok
is unavailable or its verified output does not meet the bar. Size per the judgment doc:

- **trivial** → a single rw lane on Grok 4.5 low or medium; the host still verifies.
- **default** → one writer lane, the `code` engine, `--effort medium`.
- **large and separable** → split the spec into **file-disjoint work packages** —
  only along genuinely independent seams (shared files, barrel exports, lockfiles,
  shared configs mean it's one package) — and run one writer lane per package in
  parallel. When in doubt, one writer.

Declare the sizing in one line before launching (e.g. `Sizing: 2 workers (grok ×
grok, medium) — packages: api/, cli/`). Run `plx-preflight --repo <repo>
--require-<engine>` for each engine the run will use.

## Pipeline (run in order)

1. **Write the spec brief(s).** `<tmp>/spec.md` (or `<tmp>/spec-<package>.md` each):
   a `## Spec` header, then the full plan verbatim — the lane runs headless and fresh;
   the brief is everything it knows beyond the repo itself. Each brief carries a
   `### Pre-existing worktree state` section listing dirty paths (or
   `clean`) and instructing the worker to preserve them. If a target path is already dirty,
   include the relevant baseline-diff context. For parallel packages, each brief carries
   the shared intent plus its own scope and an explicit boundary: **"You
   own only these paths: <list>. Other paths are being edited in parallel — do not
   touch them."**

2. **Launch the writer lane(s)** — background Bash (`run_in_background`; build turns
   can outrun the 10-min foreground cap), parallel lanes in one message:

   ```
   plx-engine --engine <e> --mode rw --repo <repo> --prompt-file <tmp>/spec.md \
     --rubric worker --effort <medium|high|xhigh> --out <tmp>/build.md --log <tmp>/build.log
   ```

   - **One writer per disjoint path set** — never two lanes on overlapping paths, and
     never edit the files yourself while a lane owns them.
   - Grok lanes need the Bash sandbox disabled (`dangerouslyDisableSandbox: true`). The
     wrapper fixes their model to `grok-4.5`; size effort as `low|medium|high` (default
     `medium`) and never pass `xhigh`.
   - Exit codes: 0 ok · 1 engine failure (read the log; retry once, or escalate to a
     smarter engine per the judgment doc) · 2 your usage error · 3 not signed in → tell
     the user and stop.
   - While lanes run, prepare only the integration commands and pass signals already
     required by this task.

3. **Read the Buildout report(s)** from the out-files — summaries only; don't pull code
   bodies into your window. Each worker self-verifies; with parallel packages, run the
   repo's own checks once yourself **after all writers land** (integration — parallel
   test runs against half-built code are noise). Use the repo's toolchain binaries
   (e.g. `.venv/bin/pytest -q`, `npm test`); never `uv run` inside a sandbox.

4. **Report and stop.** Compact report:

   ```text
   Built: <what shipped>
   Sizing: <workers × engines, effort>
   Files: <from the reports — cross-checked against git status vs the Bootstrap snapshot>
   Verification: <commands + results>
   Assumptions/blockers: <from the reports, or "none">
   Next: /plx:review [scope]
   ```

   Cross-check "files touched" against `git status --short` vs the Bootstrap snapshot —
   ground truth over the worker's testimony. No review round here — that's
   `/plx:review`. This skill does not commit; version control follows the repo's own
   agent instructions. Clean up `<tmp>`.

## Hard constraints

- Never hand-construct raw `codex` / `grok` / `claude -p` commands — `plx-engine` is
  the only sanctioned path; safety is pinned inside it.
- Rubrics are injected by `--rubric` name; never paste rubric text into briefs.
- One writer per disjoint path set, always. Do not write Parallax state into the target
  repo — no `.parallax/` dirs; temp files live in `<tmp>`, cleaned up before returning.
- This skill does not commit or publish.
- Never `uv run` inside a sandbox.

Build input:

$ARGUMENTS
