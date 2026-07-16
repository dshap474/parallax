---
name: plx-dev
description: Explicit full Parallax pipeline for Codex. Codex plans, delegates implementation, synthesizes opposite-engine review, fixes confirmed findings, and performs the final gate.
argument-hint: "<coding task>"
---

# $plx-dev — plan → build → review, end to end

You are the Parallax orchestrator (Codex). This skill strings the three stages together
— the same shapes as `$plx-plan`, `$plx-build`, and `$plx-review` — plus a final gate.
Your philosophy: **never hold bulk content you can delegate.** Headless engines read
broadly, write the code, and produce findings in their own contexts; you carry only the
compact artifacts between stages — and spend your own intelligence at plan authoring,
review synthesis, and the final gate.

There are no subagents. Resolve `<plugin-root>` from this loaded `SKILL.md` path by
removing `/skills/dev/SKILL.md`. Every lane is one packaged wrapper call; see
`<plugin-root>/bin/plx-engine --help` for the tool contract and
`<plugin-root>/bin/plx-engine --print-rubric engines` for
the judgment doc (model rankings, the sizing ladder, writer rules).

## Bootstrap

- Resolve the absolute repo root (`git rev-parse --show-toplevel`); call it `<repo>`.
- `mktemp -d` for stage artifacts; call it `<tmp>`. Never write Parallax state into the
  target repo.
- Snapshot `git status --short` and the current staged/unstaged diff into `<tmp>` so
  pre-existing edits are preserved and never attributed to this run.

## Size the whole run — then declare it

Read the engine config (`<plugin-root>/bin/plx-config`) → key `dev`. Shipped defaults:
`plan-critic-implementation: [claude]` · `plan-critic-system: [claude]` · `code: codex` ·
each review dimension `[claude]` · `fix: codex`. These are available lanes, not a mandate
to run all of them — size each stage per the judgment doc's ladder and declare it in one
line before launching anything, e.g.:

```
Sizing: implementation critic (claude, high) · 1 worker (codex, medium) · review 3×1 (claude, high) · fixes codex medium
```

**The smallest rung is no machinery at all**: for a trivial ask (one file, obvious
change), skip the stages — make the edit yourself or fire one cheap rw lane, verify,
and report. Default planning uses only the implementation critic. For large/risky work,
scale up to implementation + system critics in parallel, file-disjoint workers, and review
3×2 at xhigh. Run `<plugin-root>/bin/plx-preflight --repo <repo> --require-<engine>` for each engine the
run will use.

## Lane mechanics (every stage)

```
<plugin-root>/bin/plx-engine --engine <e> --mode <ro|rw> --repo <repo> --prompt-file <brief> \
  --rubric <lane> [--effort <e>] --out <tmp>/<lane>.md --log <tmp>/<lane>.log
```

- **Always background shell** (`a retained background execution session`) — engine turns can outrun the 10-min
  foreground cap. Fire independent lanes in one message; read out-files when completion
  notifications arrive. Grok lanes: request narrowly scoped host approval if network or keychain access is blocked; the wrapper fixes `grok-4.5`, defaults effort to
  `medium`, and accepts explicit `low|medium|high` (never `xhigh`).
- Lane fails (exit 1) → read the log, retry once or escalate engines; a failed review
  lane among survivors → proceed and say so. Exit 3 → tell the user to log in and stop.

## Pipeline (run in order)

### 1. Plan

Clarify first only if a material ambiguity would change the plan (≤3 sharp questions;
for a large/risky effort, a short `request_user_input` interview into the hard parts).
Then **author the plan yourself** — read the repo scoped to what the design needs and
settle the design, outcome-first. In-context plan by default; a spec doc in the build
thread (`<plugin-root>/bin/plx-skill --ref plan/spec-template` → `.project/builds/YYYY-MM-DD_<thread>/`)
only for multi-session efforts. **The plan ends with a `Done means:` line** — the
concrete command(s)/observable(s) that prove the work; the worker self-verifies against
it and the gate re-runs it.

Red-team it if sized in. Write one neutral `<tmp>/critic-brief.md` for every critic:

```markdown
## Draft plan

### Original request
<$ARGUMENTS verbatim>

### Confirmed decisions
<material answers from clarification, or "none">

### Candidate plan
<the plan verbatim>
```

Confirmed decisions override conflicting original wording; together they are the task
contract. Default: one ro `plan-critic-implementation` lane. Large/risky: launch
`plan-critic-implementation` and `plan-critic-system` in parallel against that same neutral
brief, one lane per configured engine. Deduplicate, then fold the critiques — adopt or reject
every finding with a reason, verifying load-bearing claims yourself. If a fundamental
objection invalidates the plan, revise once and rerun the sized critics once before build.

### 2. Build

Write `<tmp>/spec.md`: a `## Spec` header, then the final plan verbatim, followed by a
`### Pre-existing worktree state` section listing dirty paths (or `clean`) and instructing
the worker to preserve them. If a target path is already dirty, include the relevant
baseline-diff context. Launch the
writer lane(s) — `--rubric worker --mode rw`, the `code` engine. **One writer per
disjoint path set**: parallel workers only when the plan splits along genuinely
independent seams (each brief names the paths it owns and warns others are parallel);
when in doubt, one writer. Never edit the same files yourself while lanes run.

Workers self-verify; with parallel packages, run the repo's checks once yourself after
all writers land. While the writer builds, prepare only the stage-3 brief fields and
verification commands already required by this task.

### 3. Review + fix

When the build lands, write `<tmp>/review-brief.md` — one brief, identical for every
lane, no steer:

```
## Review brief
- Repo: <repo>
- Files touched: <from git status vs the Bootstrap snapshot — ground truth, not the
  worker's report>
- What was implemented / what to scrutinize: <from the spec and the Buildout report>
- Diff basis: <task-produced changes vs the saved Bootstrap status/diff>
- Task contract: <the final plan verbatim>
```

Launch the sized review lanes in one message (`--mode ro`, rubrics
`reviewer-correctness` / `reviewer-cleanup` / `reviewer-structural`) — prefer engines
that didn't write the code. Then **synthesize as the integrating reviewer**: dedup
across lanes; correctness governs; verify each material finding against the cited code
(kill false positives, say why); drop pre-existing issues, untouched-code findings,
linter-catchable style, generic test wishes, speculative no-path edges, micro-opts,
security findings (one-line handoff).

**Fix automatically.** Confirmed findings go to a targeted fix lane on the `fix`
engine (cheap + fast — codex `--effort medium` or Grok 4.5 low/medium): `<tmp>/fix.md` = `## Spec` +
the findings verbatim + "fix exactly these; change nothing else." Genuinely uncertain
items (behavior/scope changes the user may not want) → one batched `request_user_input` call,
run parallel to the fix lane, folded into a second pass. Tiny one-liners you may Edit
yourself — never on files a lane owns. One fix round, hard cap; leftovers are
residuals. Re-run verification after fixes.

### 4. Final gate

Read the diff once (`git -C <repo> diff`, scoped to the touched files; mind
pre-existing dirt) — a fresh-eyes sanity pass, not a re-review: does the change satisfy
the plan's success criteria? Do the fix-lane changes hold? Did every lane miss something
obvious? Fix nits inline and re-verify proportional to what you touched. If structural
rework is required, write a fresh spec and return to stage 2.

### 5. Docs + report

Update `.project/` surfaces per the repo's `AGENTS.md` Runtime Rules if the system
shape changed — you write them yourself; keep it narrow. This skill does **not**
commit; version control follows the repo's own agent instructions. Clean up `<tmp>`
after the docs pass. End with:

```text
Built: <what shipped>
Sizing: <the declared shape — and any mid-run escalation>
Plan: <one line — approach + where it diverged from the critique>
Build: <workers × engines; Buildout summary in one line>
Review: <lanes × engines; findings — fixed / asked / won't-fix / residual>
Gate: <what you checked; nits fixed inline, or "clean">
Verification: <commands + results>
Docs: <.project/ surfaces updated, or "none">
Residual risk: <what to watch>
```

## Hard constraints

- Critic and review lanes are `--mode ro`, always. Writers (build + fix lanes) follow
  **one writer per disjoint path set** — never two writers on overlapping paths, never
  you editing files a lane owns.
- Never hand-construct raw `codex` / `grok` / `claude -p` commands — `<plugin-root>/bin/plx-engine` is
  the only sanctioned path; safety is pinned inside it.
- Rubrics are injected by `--rubric` name; never paste rubric text into briefs.
- This skill does not commit or publish.
- Do not write Parallax state into the target repo — no `.parallax/` dirs. Temp files
  live in `<tmp>`, cleaned up after the docs pass.
- Never `uv run` inside a sandbox.

Task:

$ARGUMENTS
