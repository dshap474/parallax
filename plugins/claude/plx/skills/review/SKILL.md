---
name: review
description: Standalone multi-lane code review with automatic fixes. Direct invocation runs Grok correctness, cleanup, and structural lanes in parallel by default, adds a Grok security lane when triggered, synthesizes, then applies confirmed fixes as small targeted edits. Explicit whole-round engine overrides win; say "report only" to skip fixes.
argument-hint: "<scope> [with all Codex|Claude|Grok lanes] [at <effort> effort] [report only]"
disable-model-invocation: true
user-invocable: true
---

# /plx:review

Run independent read-only review lanes, verify their findings, and fix confirmed issues
with small targeted edits. A report-only request stops after synthesis.

Use the packaged helpers on PATH.

## Prepare the round

Resolve `<repo>` with `git rev-parse --show-toplevel`. Establish the requested files,
change range, and baseline from the user and Git status/diffs. Read enough code to make
the scope accurate. Save the status and diffs so fixes preserve existing work.

Create `<tmp>` with `mktemp -d "${TMPDIR:-/tmp}/plx-review.XXXXXX"`. Write the request
and scope to `<tmp>/task.md`; keep every lane prompt directly in `<tmp>`.

Run exactly three core roles: `reviewer-correctness`, `reviewer-cleanup`, and
`reviewer-structural`. Default all three to Grok `grok-4.5` at `medium`. Honor an
explicit whole-round engine override, such as `with all Grok lanes`, `with all Claude
lanes`, or `with all Codex lanes`. Claude defaults to `high`, Codex to `xhigh`.
Apply model/effort overrides to the whole round.
Do not use mixed per-role routing or YAML bindings. Dev invokes this same Review skill.

Add `reviewer-security` when requested or when scope touches auth, permissions,
secrets/config, shell/subprocess execution, sandboxing, network clients, dependencies,
lockfiles, CI, deserialization, or another trust boundary. Otherwise report
`Security: not run`.

Declare the roles, engines, effort, and host-owned fixes; save to `<tmp>/shape.txt`.
Run `plx-preflight --repo <repo> --require-<engine> --model <model>` for the selected engine.
For Grok calls and preflight, disable the Bash sandbox (`dangerouslyDisableSandbox: true`); keep Grok's kernel sandbox active.

## Launch

Write one neutral `<tmp>/brief.md`, identical for every lane:

```
## Review brief
- Repo: <repo>
- Files touched: <scope>
- Intended behavior and review focus: <task requirements and review scope>
- Diff basis: <exact baseline or commit range>
- Spec source: <task, plan, or doc; otherwise derive from code and tests>
```

Keep lane selection, model/effort settings, and report-only or fix instructions in the
host context. Each lane reviews the supplied target under its rubric. Keep suspicions
and proposed verdicts out of the brief. Launch all selected dimensions
in parallel in retained background sessions:

```
plx-engine --engine <e> --mode ro --repo <repo> --prompt-file <tmp>/brief.md \
  --rubric reviewer-<dimension> --model <model> --effort <effort> \
  --out <tmp>/<e>-<dimension>.md --log <tmp>/<e>-<dimension>.log
```

Use packaged wrappers and named rubrics; no raw engine commands, pasted rubrics, or
subagents. On exit 1, inspect the log; proceed with surviving lanes and disclose the
omission. Correct exit-2 usage errors. Exit 3 requires authentication; report it.
Missing required lanes make the round partial.

## Synthesize and fix

Deduplicate by root cause and try to disprove each material finding against the code.
Correctness determines which objects belong in scope before cleanup or structural
remedies. Reject false positives with a reason. Filter unrelated pre-existing issues
(unless this is a whole-file audit), untouched code without a causal link, linter-only
style, generic test/doc wishes, speculative unreachable cases, and optimizations without
material cost. Read further where the reports reveal a gap.

If a core lane finds a concrete security risk, run the security lane if possible or
retain the risk as a named residual. Rank confirmed findings by severity. Ask about
remedies only when intent, behavior, scope, or an interface needs a user decision;
batch those questions. For report-only requests, deliver findings and a repair plan.

Fix directly after every lane has returned. Apply confirmed, unambiguous remedies in
one bounded fix round, including approved answers. Preserve unrelated edits. Leave
build-sized remedies and remaining issues as residuals and recommend `/plx:build`.
Re-read your diff and run the relevant repository checks. Never `uv run` inside a sandbox.
Follow repository instructions for local commits; this skill grants no publication authority.

## Finish

Report scope and lane coverage, confirmed and rejected findings, security status, fixes,
open decisions, residuals, and verification commands/results. Use a compact natural
format; omit empty sections. Report-only verification may pass when all required lanes
and finding checks completed.

Keep runtime output out of the repo, including `.parallax/`. Before every handled return,
including report-only and errors, finish the run and clean up:

```
plx-eval finish --skill review --host claude --repo <repo> --run-dir <tmp> \
  --host-model <actual host model if known, otherwise unknown> \
  --task-file <tmp>/task.md --shape-file <tmp>/shape.txt \
  --outcome <pass|fail|partial|aborted> --verification <pass|fail|not-run> \
  || echo "plx-eval finish failed (non-fatal)" >&2
plx-clean-temp <tmp>
```

Recorder failure is non-fatal; an interrupted run may remain incomplete.

Request:

$ARGUMENTS
