---
name: simplify
description: Improve changed code without hunting for correctness bugs. Run four independent read-only PLX lanes for reuse, simplification, efficiency, and altitude, then validate, deduplicate, and directly apply the confirmed behavior-preserving fixes. Use for explicit code-quality cleanup after an implementation; say "report only" to skip fixes.
argument-hint: "<scope> [with all Codex|Claude|Grok lanes] [at <effort> effort] [report only]"
disable-model-invocation: true
user-invocable: true
---

# /plx:simplify — improve changed code

Improve the quality of the changed code; do not hunt for correctness bugs. Run four
independent read-only PLX lanes for reuse, simplification, efficiency, and altitude,
synthesize their findings, then apply the confirmed behavior-preserving fixes yourself.
Use `/plx:review` for correctness review.

There are no subagents. Every lane is a `plx-engine` call. You are the Claude host:
resolve scope, launch lanes, synthesize, fix, and verify. If the user says `report only`
or equivalent, stop after synthesis without editing source files.

## Bootstrap

1. Resolve `<repo>` with `git rev-parse --show-toplevel` and snapshot
   `git status --short` so pre-existing work is preserved.
2. Resolve one review scope, in order:
   - the explicit PR, branch, commit range, file, or directory in the request;
   - otherwise `@{upstream}...HEAD` when an upstream exists;
   - otherwise `main...HEAD` when `main` exists;
   - otherwise `HEAD~1...HEAD`.
   Include `git diff HEAD` when working-tree changes exist or the selected range is
   empty. Surrounding code may be read later to verify reuse or ownership, but findings
   remain anchored to this scope.
3. Create `<tmp>` with `mktemp -d "${TMPDIR:-/tmp}/plx-simplify.XXXXXX"`.
   Write the original request plus resolved scope to `<tmp>/task.md`.
4. Read `plx-config` key `simplify`. The shipped binding is four Codex lanes.

## Resolve the fixed shape

Always run exactly these four read-only roles:

| Role | Rubric |
| --- | --- |
| `simplify-reuse` | `simplifier-reuse` |
| `simplify-simplification` | `simplifier-simplification` |
| `simplify-efficiency` | `simplifier-efficiency` |
| `simplify-altitude` | `simplifier-altitude` |

The current request may replace the configured engine for the whole round:

- `with all Grok lanes` → all four roles use Grok;
- `with all Claude lanes` → all four roles use Claude;
- `with all Codex lanes` → all four roles use Codex.

Do not infer an override from model names mentioned only as task content. Mixed
per-dimension routing is not supported. Explicit model and effort values pass through
unchanged when supported. With no explicit effort, use Claude `high`, Codex `xhigh`, or
Grok `high`; never send `xhigh` to Grok.

Declare and write one line to `<tmp>/shape.txt` before launching, for example:

```text
Sizing: simplify 4×1 (grok high) · reuse + simplification + efficiency + altitude · fixes: host
```

Keep every prompt file directly under `<tmp>` so its `plx-simplify.<suffix>` basename
groups all trace rows. Preflight each distinct selected engine once with
`plx-preflight --repo <repo> --require-<engine>`. Close the run with `plx-eval finish`
before every handled early return; recorder failure is non-fatal.

## Run the lanes

1. Write one identical neutral brief to `<tmp>/brief.md`:

   ```text
   ## Simplify brief
   - Repo: <repo>
   - Scope: <explicit target or changed-file list>
   - Diff basis: <exact range and whether working-tree changes are included>
   - Requested outcome: improve changed code without changing behavior
   ```

   Do not add suspicions, analysis, or different context per lane.

2. Launch one background Bash call per lane together so all four run concurrently
   (`run_in_background`):

   ```text
   plx-engine --engine <engine> --mode ro --repo <repo> \
     --prompt-file <tmp>/brief.md --rubric <simplifier-rubric> [--model <model>] \
     --effort <effort> \
     --out <tmp>/<engine>-<dimension>.md --log <tmp>/<engine>-<dimension>.log
   ```

   Rubrics are injected only by name; never paste them into the brief. Never construct
   raw engine CLI commands. Grok calls need the Bash sandbox disabled
   (`dangerouslyDisableSandbox: true`); the wrapper's kernel sandbox remains the
   confinement boundary.

3. Wait for all four dimensions. On exit `1`, inspect the log and retry that dimension
   once with the same selected engine, using `-retry` output/log names. Exit `2` is a
   usage error; exit `3` means authentication is required. If a retry still fails,
   continue only when at least one dimension succeeded, mark the run `partial`, and name
   every missing dimension. Never substitute another engine for an explicit selection.

## Synthesize and fix

After every surviving lane returns:

1. Deduplicate findings that identify the same line or root mechanism.
2. Read cited code surgically and try to disprove every material finding.
3. Drop unrelated pre-existing debt, style-only notes, speculative micro-optimizations,
   unsupported claims, and findings without a concrete cost.
4. Keep only small remedies that preserve intended behavior and remain close to the
   reviewed change.

Do not solicit correctness or security review. If a concrete correctness or security
issue appears incidentally, leave it unchanged, report it as out of scope, and recommend
`/plx:review`.

Unless this is report-only, apply the confirmed fixes yourself in one bounded round,
only after all lanes stop. Skip and note anything that may change behavior, needs a wide
refactor, extends well outside scope, lacks evidence, or is a false positive. Never
launch a writer or fix lane.

## Verify and finish

Re-read the resulting diff and run checks proportionate to the touched code. Before
cleaning `<tmp>`, close the run on every normal or handled-error path:

```text
plx-eval finish --skill simplify --host claude --repo <repo> --run-dir <tmp> \
  --host-model <actual host model or unknown> --task-file <tmp>/task.md \
  --shape-file <tmp>/shape.txt --outcome <pass|fail|partial|aborted> \
  --verification <pass|fail|not-run> \
  || echo "plx-eval finish failed (non-fatal)" >&2
```

Report the scope, lane shape, confirmed and rejected finding counts, fixed items, skipped
items, missing dimensions, and verification. Clean only with `plx-clean-temp <tmp>`.

## Hard constraints

- All four lanes use `--mode ro`; the host is the only writer.
- Use packaged `bin/` tools and named `prompts/` rubrics only.
- Do not create `.parallax/` or other runtime state in the target repository.
- Do not commit or publish.
- Never `uv run` inside a sandbox.

Request:

$ARGUMENTS
