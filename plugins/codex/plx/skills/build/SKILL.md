---
name: build
description: Delegate an accepted spec to one fresh Codex gpt-5.6-sol High build worker that implements it, runs three read-only Grok 4.6 XHigh review lanes itself, fixes confirmed findings itself, runs the complete relevant verification suite, and reports; the host bootstraps, gate-checks, and records.
argument-hint: "<accepted spec path, or omit when an accepted spec is already in this conversation>"
---

# $plx:build — delegate implement → review → fix → verify to one worker

You are the Parallax orchestrator (Codex). Use this skill only after the user has an
accepted implementation spec. Push the whole build down into one fresh Codex build
worker: it implements the spec, runs the independent Grok review itself, fixes confirmed
findings itself, runs the complete relevant verification suite, and returns a report. You
bootstrap the run, gate-check the result, record the trace, and report.

This standalone workflow is separate from `$plx:dev`. It always launches exactly one
fresh same-host worker lane: Codex `gpt-5.6-sol` at `high` by default. An explicit
current-message model or effort request for the worker overrides that default. The active
host never implements, reviews, or fixes alongside the worker. Resolve `<plugin-root>`
from this loaded `SKILL.md` path by removing `/skills/build/SKILL.md`. Engine execution
is allowed only through packaged `<plugin-root>/bin/` tools.

## Require an accepted spec

Accept either:

1. a spec document path supplied in the arguments; or
2. an explicitly accepted spec already present in this conversation.

Do not turn a raw task into a spec and do not re-plan. If no accepted spec exists, stop
and direct the user to `$plx:plan` or `$plx:goal-spec`. If the named spec is missing or
ambiguous about the intended behavior, stop and ask for the missing decision.

Read the spec and extract its requirements, constraints, and observable acceptance
criteria. Identify the repository's relevant test, typecheck, lint, build, and smoke
commands; the worker brief names them. Do not weaken or silently rewrite the spec.

## Bootstrap

- Resolve the absolute repository root (`git rev-parse --show-toplevel`); call it
  `<repo>`.
- Resolve the absolute packaged wrapper path `<plugin-root>/bin/plx-engine`; call it
  `<plx-engine>`. The worker launches its review lanes through this exact path.
- Create `<tmp>` with `mktemp -d "${TMPDIR:-/tmp}/plx-build.XXXXXX"`.
- Record the baseline commit from `git rev-parse HEAD` in `<tmp>/baseline-head.txt`.
- Snapshot `git status --short` to `<tmp>/status-baseline.txt` and the staged and
  unstaged diffs to `<tmp>/diff-staged-baseline.patch` and
  `<tmp>/diff-unstaged-baseline.patch`. Preserve all pre-existing work and never
  attribute it to this build.
- Write the accepted spec verbatim to `<tmp>/task.md`.
- Write `Implementation: 1× fresh codex (gpt-5.6-sol high) owns implement · review: 3×1 (grok-4.6 xhigh, worker-run) · fixes: worker · verification: full relevant suite (worker-run) · host: bootstrap + gate`
  to `<tmp>/shape.txt` and declare that shape before mutation.
- Run `<plugin-root>/bin/plx-preflight --repo <repo> --require-codex --require-grok`
  before mutation. If either required engine is unavailable, record an aborted run and stop without
  implementing.

Keep all run files directly in `<tmp>` so its `plx-build.<suffix>` basename groups the
worker lane and the review lanes it launches. Call `<plugin-root>/bin/plx-eval finish` before
every handled return. Recorder failure is non-fatal; interruption may leave the run incomplete.

## Repository commits and publication

The target repository's instructions and the accepted spec govern local commits:

- The worker may create local commits when the accepted spec or the target repository's
  agent instructions explicitly require or authorize them. If neither does, the Build
  changes stay uncommitted.
- Honor required checkpoint ordering. For example, when a repository requires a
  preregistration-only commit before executable code, the worker creates that exact narrow
  checkpoint before implementation and then continues.
- Stage only Build-owned paths or isolated Build-owned hunks. Never use `git add -A`, never
  include pre-existing work, and inspect `git diff --cached` before every commit. If a file
  had pre-existing changes that cannot be isolated safely, leave it uncommitted and report
  the blocker.
- Never amend, reset, rebase, rewrite, or delete existing commits or worktree changes.
- Record every created commit hash and purpose for the final report.
- Never push, open a pull request, merge, tag, release, deploy, or otherwise publish
  externally unless the user separately authorizes that action under the target repository's
  rules. Target-local artifacts explicitly required by the accepted spec are allowed.

## Pipeline

### 1. Delegate the whole build to one fresh worker

Create `<tmp>/writer-brief.md` with the exact accepted spec under the required header,
followed by the run context the worker needs:

```
## Spec
<accepted spec verbatim>

## Build run context
- Repo: <repo>
- Run directory: <tmp> (write review-brief.md and every lane out/log file here)
- Engine wrapper: <plx-engine> (absolute path; the only way to launch a lane)
- Baseline commit: <contents of <tmp>/baseline-head.txt>
- Baseline snapshots: <tmp>/status-baseline.txt, <tmp>/diff-staged-baseline.patch,
  <tmp>/diff-unstaged-baseline.patch (pre-existing work; never stage or review it)
- Spec source: <path or "accepted conversation spec">
- Verification suite: <the repository's relevant test, typecheck, lint, build, and
  smoke commands>
- Security lane: <"required" when requested or when the change touches auth,
  permissions, secrets/config, shell or subprocess execution, sandboxing, network
  clients, dependencies/lockfiles, CI workflows, deserialization, or another trust
  boundary; otherwise "not triggered">
- Review lanes (launch all three in parallel after implementation):

<plx-engine> --engine grok --mode ro --repo <repo> \
  --prompt-file <tmp>/review-brief.md --rubric reviewer-correctness --model grok-4.6 --effort xhigh \
  --out <tmp>/grok-correctness.md --log <tmp>/grok-correctness.log

<plx-engine> --engine grok --mode ro --repo <repo> \
  --prompt-file <tmp>/review-brief.md --rubric reviewer-cleanup --model grok-4.6 --effort xhigh \
  --out <tmp>/grok-cleanup.md --log <tmp>/grok-cleanup.log

<plx-engine> --engine grok --mode ro --repo <repo> \
  --prompt-file <tmp>/review-brief.md --rubric reviewer-structural --model grok-4.6 --effort xhigh \
  --out <tmp>/grok-structural.md --log <tmp>/grok-structural.log

  When the security lane is required, also run `--rubric reviewer-security` with the
  same model and effort to <tmp>/grok-security.md / .log.
```

Honor an explicit whole-round review model or effort override by editing those lane
commands; otherwise keep the standalone Build review at `grok-4.6` and `xhigh`.

Launch exactly one fresh Codex build worker in a retained/background shell session:

```
<plugin-root>/bin/plx-engine --engine codex --mode rw --repo <repo> \
  --prompt-file <tmp>/writer-brief.md --rubric build-worker \
  --build-writer-full-access \
  --model gpt-5.6-sol --effort high \
  --out <tmp>/writer.md --log <tmp>/writer.log
```

The worker is the single owner of implementation, review, fixes, and verification. It
must follow the accepted spec and target-repository instructions, including any required
local checkpoint ordering, keep the change narrow, preserve pre-existing work, write
`<tmp>/review-brief.md`, run the review lanes above, validate and fix confirmed findings
in one bounded round, and run the complete relevant verification suite. The host does not
implement, review, or fix alongside it. Full host access exists only so this lane can
write Git metadata, create authorized local commits, and launch its packaged review lanes;
it does not expand the accepted spec, repository scope, publication authority, or
external-system authority.

### 2. Gate-check the worker

Wait for the worker. Read `<tmp>/writer.md`, the lane out-files it produced, the
repository status, and the Build-owned diff relative to `<tmp>/baseline-head.txt` and the
Bootstrap snapshots. This scope must
include committed and uncommitted Build changes while excluding pre-existing work.
Confirm:

- the report has the `## Build report` shape and its verification lines name the
  complete relevant repository verification suite as run against the settled
  implementation;
- every claimed commit exists, contains only Build-owned work, and the worker never
  amended or rewrote pre-existing history;
- the review lanes ran (or the report states exactly which failed after retry), and
  every confirmed finding is either fixed or listed as a residual;
- the diff stays inside the accepted spec and repository scope.

If the worker command fails, returns `[NEEDS CLARIFICATION]`, touches forbidden scope,
skips the review or verification stages without a stated blocker, or leaves an unsafe
ambiguous state, do not launch another writer, do not run the review lanes yourself, and
do not silently take over implementation or fixes. Record a failed or partial run as
appropriate and report the exact blocker. If a required check could not run, mark the
result partial. Never claim certainty beyond the checks the worker actually completed.

### 3. Record and report

Write the final report to `<tmp>/report.md`, then close the trace before cleaning up:

```
<plugin-root>/bin/plx-eval finish --skill build --host codex --repo <repo> --run-dir <tmp> \
  --host-model <actual host model if known, otherwise unknown> \
  --task-file <tmp>/task.md --shape-file <tmp>/shape.txt --report-file <tmp>/report.md \
  --outcome <pass|fail|partial|aborted> --verification <pass|fail|not-run> \
  || echo "plx-eval finish failed (non-fatal)" >&2
```

Report:

```text
Built: <what changed>
Implementation: <fresh Codex build worker result and summary>
Spec coverage: <requirements satisfied; anything missing>
Review: <lanes completed; confirmed, rejected, and residual findings; Security: <run|not run>>
Fixed: <confirmed findings fixed by the worker, or "none">
Files: <files attributable to this build>
Commits: <local commit hashes and purposes, or "none">
Local artifacts: <target-local artifacts created or published, or "none">
External publication: <authorized actions completed, or "none">
Verification: <commands and results, as run by the worker>
Residuals: <blockers or uncertainty, or "none">
```

Clean up with `<plugin-root>/bin/plx-clean-temp <tmp>`. Local commits and target-local artifacts follow the
repository policy above; remote publication always requires separate authority.

## Hard constraints

- An accepted spec is required. Do not plan inside Build.
- Launch exactly one fresh Codex build worker (`gpt-5.6-sol` `high` unless explicitly
  overridden); never launch a second writer or a fix lane, and never run the review lanes
  or apply fixes in the host session. The host owns only bootstrap, gate-checking,
  trace recording, and reporting.
- Review lanes are read-only, launched by the worker through the packaged wrapper, and
  run only after implementation.
- Full host access is limited to the one fresh build-worker-rubric implementation lane.
  Every review lane remains read-only, and no other Parallax writer inherits this
  exception.
- Never hand-construct raw `codex`, `grok`, or `claude -p` commands.
- Inject rubrics by name; never paste rubric text into prompts.
- Never create `.parallax/` or leave runtime output in the target repository.
- Never include pre-existing work in a Build-created commit, and never perform remote Git
  or external publication without separate authority.
- Never `uv run` inside a sandbox.
