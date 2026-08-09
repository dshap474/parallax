---
name: build
description: Implement an accepted spec directly in the Claude host, review the result with three read-only Grok lanes, fix confirmed findings, run the complete relevant verification suite, and report.
argument-hint: "<accepted spec path, or omit when an accepted spec is already in this conversation>"
disable-model-invocation: true
user-invocable: true
---

# /plx:build — implement, review, fix, verify

You are the Parallax orchestrator (Claude). Use this skill only after the user has an
accepted implementation spec. You implement that spec directly in this session, run an
independent Grok review, fix confirmed findings yourself, run the complete relevant
verification suite, and report the result.

This standalone workflow is separate from `/plx:dev`. It does not launch a writer lane
or subagent. Engine execution is allowed only through packaged `plx-*` tools.

## Require an accepted spec

Accept either:

1. a spec document path supplied in the arguments; or
2. an explicitly accepted spec already present in this conversation.

Do not turn a raw task into a spec and do not re-plan. If no accepted spec exists, stop
and direct the user to `/plx:plan` or `/plx:goal-spec`. If the named spec is missing or
ambiguous about the intended behavior, stop and ask for the missing decision.

Read the spec and extract its requirements, constraints, and observable acceptance
criteria. Identify the repository's relevant test, typecheck, lint, build, and smoke
commands. Do not weaken or silently rewrite the spec.

## Bootstrap

- Resolve the absolute repository root (`git rev-parse --show-toplevel`); call it
  `<repo>`.
- Create `<tmp>` with `mktemp -d "${TMPDIR:-/tmp}/plx-build.XXXXXX"`.
- Snapshot `git status --short` and the staged and unstaged diffs into `<tmp>`.
  Preserve all pre-existing work and never attribute it to this build.
- Write the accepted spec verbatim to `<tmp>/task.md`.
- Write `Implementation: host · review: 3×1 (grok medium) · fixes: host · verification: full relevant suite`
  to `<tmp>/shape.txt` and declare that shape before mutation.
- Run `plx-preflight --repo <repo> --require-grok` before mutation. If Grok is
  unavailable, record an aborted run and stop without implementing.

Keep all run files directly in `<tmp>` so its `plx-build.<suffix>` basename groups the
captured review lanes. Call `plx-eval finish` before every handled return. Recorder
failure is non-fatal; interruption may leave the run incomplete.

## Pipeline

### 1. Implement the accepted spec

Read the relevant repository code and implement every requirement directly with your
native editing tools. Keep the change narrow, follow the repository's instructions,
and preserve pre-existing edits. Run targeted checks while working when they shorten
the feedback loop.

Do not launch a write-mode engine or a worker rubric. The active host is the only
writer for the entire Build run.

### 2. Review with Grok

After implementation is complete, determine the changed-file scope relative to the
Bootstrap snapshot. Write one neutral brief to `<tmp>/review-brief.md`:

```
## Review brief
- Repo: <repo>
- Files touched: <changed files from this build>
- What was implemented: <short summary grounded in the accepted spec>
- Diff basis: <working tree relative to the Bootstrap snapshot>
- Spec source: <path or accepted conversation spec>
```

Launch these three read-only Grok lanes in parallel:

```
plx-engine --engine grok --mode ro --repo <repo> \
  --prompt-file <tmp>/review-brief.md --rubric reviewer-correctness --effort medium \
  --out <tmp>/grok-correctness.md --log <tmp>/grok-correctness.log

plx-engine --engine grok --mode ro --repo <repo> \
  --prompt-file <tmp>/review-brief.md --rubric reviewer-cleanup --effort medium \
  --out <tmp>/grok-cleanup.md --log <tmp>/grok-cleanup.log

plx-engine --engine grok --mode ro --repo <repo> \
  --prompt-file <tmp>/review-brief.md --rubric reviewer-structural --effort medium \
  --out <tmp>/grok-structural.md --log <tmp>/grok-structural.log
```

Honor an explicit whole-round model or effort override. Raise Grok to `high` for large
or risky scope. Also run `reviewer-security` when requested or when the change touches
auth, permissions, secrets/config, shell or subprocess execution, sandboxing, network
clients, dependencies/lockfiles, CI workflows, deserialization, or another trust
boundary. Otherwise report `Security: not run`.

### 3. Validate findings and fix

Wait for every review lane. Deduplicate findings by root cause, verify each material
claim against the code, and discard false positives, pre-existing issues outside scope,
and unsupported suggestions. Fix every confirmed finding whose remedy is unambiguous,
directly in the host session. Ask before a fix that would change accepted behavior,
scope, or a public interface.

Use one bounded review/fix round. Do not launch a fix lane. If a confirmed remedy would
require a new build-sized design decision, report it as a residual instead of expanding
the accepted spec.

### 4. Run the final gate

After all fixes, run:

- every acceptance command required by the spec; and
- the complete relevant repository verification suite: tests, typechecks, lint, build,
  and smoke checks that cover the changed system.

Run the final suite against the settled implementation, not an intermediate diff. If a
required check cannot run, report the exact blocker and mark the result partial. Never
claim certainty beyond the checks actually completed.

### 5. Record and report

Write the final report to `<tmp>/report.md`, then close the trace before cleaning up:

```
plx-eval finish --skill build --host claude --repo <repo> --run-dir <tmp> \
  --host-model <actual host model if known, otherwise unknown> \
  --task-file <tmp>/task.md --shape-file <tmp>/shape.txt --report-file <tmp>/report.md \
  --outcome <pass|fail|partial|aborted> --verification <pass|fail|not-run> \
  || echo "plx-eval finish failed (non-fatal)" >&2
```

Report:

```text
Built: <what changed>
Spec coverage: <requirements satisfied; anything missing>
Review: <lanes completed; confirmed, rejected, and residual findings>
Fixed: <confirmed findings fixed by the host, or "none">
Files: <files attributable to this build>
Verification: <commands and results>
Residuals: <blockers or uncertainty, or "none">
```

Clean up with `plx-clean-temp <tmp>`. This skill does not commit or publish.

## Hard constraints

- An accepted spec is required. Do not plan inside Build.
- The host directly implements and fixes. Never launch a writer or fix lane.
- Review lanes are read-only and run only after implementation.
- Never hand-construct raw `codex`, `grok`, or `claude -p` commands.
- Inject rubrics by name; never paste rubric text into prompts.
- Never create `.parallax/` or leave runtime output in the target repository.
- Never `uv run` inside a sandbox.

Build input:

$ARGUMENTS
