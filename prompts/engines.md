# Engines — the Parallax toolbox and how to choose

Parallax gives the orchestrator **tools, not a script**: three coding engines, each
drivable headless through one wrapper, plus a set of lane rubrics. You decide which
engines to use for which work, and how much machinery a task deserves; this doc carries
the judgment.

## The toolbox

One wrapper, `plx-engine` (on PATH, shipped in the plugin's `bin/`):

```
plx-engine --engine codex|grok|claude --mode ro|rw --repo <abs-path> \
  --prompt-file <brief> [--rubric <name>] [--effort <e>] [--model <m>] \
  (--stdout | --out <f> --log <f>)
```

Safety is pinned inside the wrapper per engine (sandboxes, config isolation); callers
never touch raw engine CLIs. Run `plx-engine --help` for the full contract.

Rubrics live beside this file and are injected by name — the caller's brief file must
open with the section header the rubric expects:

| `--rubric`            | lane                          | brief opens with    |
| --------------------- | ----------------------------- | ------------------- |
| `reviewer-correctness`| behavioral-defect review      | `## Review brief`   |
| `reviewer-cleanup`    | reuse/simplification review   | `## Review brief`   |
| `reviewer-structural` | maintainability review        | `## Review brief`   |
| `planner`             | architecture consulting       | `## Task brief`     |
| `plan-critic-implementation` | checkout/execution red-team | `## Draft plan` |
| `plan-critic-system`  | system/design red-team        | `## Draft plan`     |
| `worker`              | implementation / fixes (rw)   | `## Spec`           |

## Models (rankings — higher is better)

Cost reflects what a call actually costs to run, not list price. Intelligence is how
hard a problem you can hand the model unsupervised. Taste covers UI/UX, code quality,
API design, and copy. *(Scores are shipped defaults — tune them to your own limits.)*

| model              | how to call                                  | cost | intelligence | taste |
| ------------------ | -------------------------------------------- | ---- | ------------ | ----- |
| gpt-5.5            | `--engine codex` (default model)             | 9    | 8            | 5     |
| grok-composer-2.5  | `--engine grok` (no model/effort knobs)      | 9    | 5            | 4     |
| sonnet-5           | `--engine claude --model sonnet`             | 5    | 5            | 7     |
| opus-4.8           | `--engine claude` (default model)            | 4    | 7            | 8     |
| fable-5            | you — the orchestrator; never delegated      | 2    | 9            | 9     |

How to apply:

- **Defaults, not limits.** You have standing permission to override any binding in
  `config/parallax.yaml`: if a cheaper model's output doesn't meet the bar, rerun the
  work on a smarter engine or higher effort without asking. Judge the output, not the
  price tag — escalating costs less than shipping mediocre work. This permission changes
  only model or effort; it never expands task scope, target resources, credentials,
  permissions, or allowed side effects.
- **When axes conflict for anything that ships: intelligence > taste > cost.** Cost is
  a tie-breaker only.
- **Bulk / mechanical work** (clear-spec implementation, migrations, data analysis) →
  gpt-5.5 or grok — effectively free.
- **Anything user-facing** (UI, copy, API design) needs **taste ≥ 7** — opus, or keep
  the work with you.
- **Reviews** → a smart model, plus optionally a cheap extra perspective. Always prefer
  a *different* engine than the one that wrote the code — independence catches what
  self-review can't.
- **Targeted fixes from a review** → fast and cheap (grok composer, or codex at
  `--effort medium`) — small scoped fixes don't need taste.
- **Effort**: `high` is the default for reviews and builds; reserve `xhigh` for
  cross-file contract changes, concurrency, data-integrity or money paths, and wide
  refactors. `medium` is fine for mechanical fixes and trivial questions.
- **Fable is never delegated.** You are fable — spend yourself where judgment is the
  product (plan authoring, review synthesis, the final gate), not on bulk reads or
  mechanical edits.

## Sizing the run (the escalation ladder)

Config bindings are the **floor shape**, not the ceiling or the mandate. Before
launching lanes, size the task and **declare the shape you chose in one line** (e.g.
`Sizing: implementation critic (codex, high) · 1 worker (claude) · review 3×1
(codex, high)`) — it
gives the user a veto point before tokens burn. Scale down as readily as up.

| scale | plan | build | review |
| --- | --- | --- | --- |
| **trivial** — one file, obvious change | none — decide and go | edit it yourself, or one rw lane | read the diff yourself |
| **small** — clear task, low blast radius | plan in-context, no critic | 1 worker | 1 lane (correctness only) |
| **default** | plan in-context + implementation critic | 1 worker | 3 dims × 1 engine |
| **large / risky** | spec doc + implementation and system critics | parallel file-disjoint workers | 3 dims × 2 engines, xhigh |

Standalone `/plx:plan` deliberately overrides the default plan rung: every explicit
invocation runs both critic dimensions in parallel. Shipped Codex bindings use
`gpt-5.6-sol` at `xhigh`; explicit config or current-message overrides win. Both dimensions
must return before the plan is final. `/plx:dev` keeps the table's proportional plan sizing
as part of the larger end-to-end run.

Scale-up signals: cross-file contracts, concurrency, data-integrity or money paths,
wide refactors, high ambiguity, code you can't easily verify. Scale-down signals: one
file, an obvious mechanism, strong existing tests, a change you can read in one sitting.
The smallest rung is **no machinery at all** — for a trivial ask, doing the work
directly beats orchestrating it.

Plan artifacts follow the same logic: a plan is a chat message by default; write it to
`.project/builds/<thread>/` only when the effort is multi-session or another agent must
consume it later. A spec doc for a one-shot task is overhead, not rigor.

## Running lanes

- **Always background Bash.** Engine turns can run 10–40+ minutes; foreground Bash caps
  at 10. Launch with `run_in_background` and `--out <f> --log <f>`, fire independent
  lanes in one message so they run concurrently, and synthesize when the harness reports
  completion. Results live on disk — read the out-files selectively; don't pull bulk
  content into your own window.
- **Grok calls need the Bash sandbox disabled** for the call
  (`dangerouslyDisableSandbox: true`) — grok needs network/keychain access the sandbox
  blocks; grok's own kernel sandbox still confines it. Grok takes no `--model`/`--effort`.
- **If a lane fails (exit 1)**: read its log, then retry once — same engine, or a
  smarter one if the failure looks like capability. If a review lane fails and others
  succeeded, proceed with the survivors and say so. **If a lane hangs** well past its
  expected runtime, check the log, kill it, and relaunch rather than waiting forever.
- Exit codes are uniform: 0 ok · 1 engine failure · 2 usage error · 3 not signed in
  (tell the user to log in to that engine).

## Writers

- **One writer per disjoint path set.** Any number of parallel read-only lanes; rw lanes
  may run in parallel **only** when their file sets don't overlap — each writer's brief
  must name the paths it owns and state that other paths are being edited in parallel.
  Never edit a file yourself while a lane owns it. When in doubt, one writer.
- The sandboxes are repo-wide — path disjointness is brief discipline, not enforced.
  Split work only along genuinely independent seams; shared files (barrel exports,
  lockfiles, shared configs) mean the work is one package.
- **Verification runs after all writers land** — parallel test runs against half-built
  code in a shared worktree are noise.
