---
name: build
description: Build an accepted spec through one fresh Codex gpt-5.6-sol High worker. The worker owns implementation, Grok review, confirmed fixes, and full relevant verification; the host bootstraps and gate-checks.
argument-hint: "<accepted spec path, or omit when an accepted spec is already in this conversation>"
---

# $plx:build

Build an accepted spec through exactly one fresh Codex worker. The worker owns
implementation, review, fixes, and verification. The host bootstraps, gate-checks,
records, and reports. Use `gpt-5.6-sol` at `high` unless the current request overrides it.

Resolve `<plugin-root>` from this loaded `SKILL.md` path by removing
`/skills/build/SKILL.md`. Use the packaged helpers in `<plugin-root>/bin/`.

## Accept the spec

Use the supplied spec path or an explicitly accepted spec in this conversation.
If neither exists, direct the user to `$plx:plan`.
Ask for any missing file or material behavior decision. Do not plan inside Build or
weaken the accepted spec. Identify the relevant repository verification commands.

## Prepare

Resolve `<repo>` with `git rev-parse --show-toplevel` and the absolute packaged
`<plugin-root>/bin/plx-engine` path as `<plx-engine>`. Create `<tmp>` with
`mktemp -d "${TMPDIR:-/tmp}/plx-build.XXXXXX"`. Save these baselines:

- `git rev-parse HEAD` in `<tmp>/baseline-head.txt`.
- `git status --short` in `<tmp>/status-baseline.txt`.
- Staged and unstaged diffs in `<tmp>/diff-staged-baseline.patch` and
  `<tmp>/diff-unstaged-baseline.patch`.

Write the accepted spec verbatim to `<tmp>/task.md`. Declare the worker, three Grok
reviewers, any security lane, worker-owned fixes and full verification, and host gate;
write that declaration to `<tmp>/shape.txt`. Keep all run files directly in `<tmp>`.
Run `<plugin-root>/bin/plx-preflight --repo <repo> --require-codex --require-grok`
before mutation. If either engine is unavailable, record an aborted run and stop.
If the host sandbox blocks Claude or Grok network/keychain access, request narrowly scoped host approval for that call; keep each lane's specified transport.

## Commit and publication authority

Follow the target repository's instructions and accepted spec for local commits,
including required checkpoint ordering. Without their authorization, leave changes
uncommitted. Stage only Build-owned paths or isolated hunks and inspect the staged
diff before committing. Never use `git add -A`, include pre-existing work, or amend,
reset, rebase, rewrite, or delete existing commits or worktree changes. If ownership
cannot be isolated, leave that work uncommitted and report the blocker.

Record created commit hashes and purposes. Remote Git operations and external
publication require explicit user authority under the repository's rules, including
pushes, pull requests, merges, tags, releases, and deployments. Target-local artifacts
required by the spec are allowed.

## Run the worker

Write `<tmp>/writer-brief.md`:

```
## Spec
<accepted spec verbatim>

## Build run context
- Repo: <repo>
- Run directory: <tmp>
- Engine wrapper: <plx-engine>
- Baseline commit: <contents of baseline-head.txt>
- Baseline snapshots: <tmp>/status-baseline.txt, <tmp>/diff-staged-baseline.patch,
  <tmp>/diff-unstaged-baseline.patch
- Spec source: <path or accepted conversation spec>
- Verification suite: <relevant test, typecheck, lint, build, and smoke commands>
- Security lane: <required or not triggered, with reason>
- Review lanes: <the commands below>
```

Require security review when requested or when the change touches auth, permissions,
secrets/config, shell/subprocess execution, sandboxing, network clients, dependencies,
lockfiles, CI, deserialization, or another trust boundary. Include these three commands
in the brief for the worker to launch in parallel after implementation:

```
<plx-engine> --engine grok --mode ro --repo <repo> \
  --prompt-file <tmp>/review-brief.md --rubric reviewer-correctness --model grok-4.6 --effort medium \
  --out <tmp>/grok-correctness.md --log <tmp>/grok-correctness.log

<plx-engine> --engine grok --mode ro --repo <repo> \
  --prompt-file <tmp>/review-brief.md --rubric reviewer-cleanup --model grok-4.6 --effort medium \
  --out <tmp>/grok-cleanup.md --log <tmp>/grok-cleanup.log

<plx-engine> --engine grok --mode ro --repo <repo> \
  --prompt-file <tmp>/review-brief.md --rubric reviewer-structural --model grok-4.6 --effort medium \
  --out <tmp>/grok-structural.md --log <tmp>/grok-structural.log
```

When required, add `reviewer-security` with the same settings and separate out/log
files. Apply explicit whole-round review model/effort overrides; `grok-4.6` stays at
`medium`. Launch the worker in a retained background session:

```
<plugin-root>/bin/plx-engine --engine codex --mode rw --repo <repo> \
  --prompt-file <tmp>/writer-brief.md --rubric build-worker \
  --build-writer-full-access --model gpt-5.6-sol --effort high \
  --out <tmp>/writer.md --log <tmp>/writer.log
```

Full host access is limited to this one build-worker lane for Git metadata and packaged
review launches. It grants no additional scope or external authority. Every reviewer
remains read-only. Use packaged wrappers and named rubrics; no raw engine commands,
pasted rubrics, or subagents. Keep runtime output out of the repo, including `.parallax/`.
Never `uv run` inside a sandbox.

## Gate and report

Wait for the worker, then read its report, review outputs, status, and Build-owned diff.
Compare against the baseline commit and snapshots to include committed and uncommitted
Build changes while excluding pre-existing work. Check spec coverage, scope, commit
ownership, review completion and finding dispositions, and the full relevant verification
suite run against the settled implementation.

If the worker fails, asks `[NEEDS CLARIFICATION]`, exceeds scope, skips a stage without
a blocker, or leaves an unsafe ambiguous state, report the blocker and a failed or partial
result. Do not launch another writer, run reviews yourself, or take over implementation
or fixes. Missing required reviews or checks make the result partial.

Write `<tmp>/report.md` with the outcome, spec coverage, changed files, review and security
results, fixes and residuals, commit hashes and purposes, local artifacts, any authorized
publication, and verification commands/results. Use a compact natural format; omit empty
sections. Claim only what the evidence supports.

Before every handled return, including errors, finish the run and then clean up:

```
<plugin-root>/bin/plx-eval finish --skill build --host codex --repo <repo> --run-dir <tmp> \
  --host-model <actual host model if known, otherwise unknown> \
  --task-file <tmp>/task.md --shape-file <tmp>/shape.txt --report-file <tmp>/report.md \
  --outcome <pass|fail|partial|aborted> --verification <pass|fail|not-run> \
  || echo "plx-eval finish failed (non-fatal)" >&2
<plugin-root>/bin/plx-clean-temp <tmp>
```

Omit `--report-file` if no report exists yet. Recorder failure is non-fatal; an
interrupted run may remain incomplete.
