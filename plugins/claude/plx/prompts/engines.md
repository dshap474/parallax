# Engines — the Parallax toolbox and how to choose

Parallax gives the orchestrator **tools, not a script**: three coding engines, each
drivable headless through one wrapper, plus a set of lane rubrics. You decide which
engines to use for which work, and how much machinery a task deserves; this doc carries
the judgment.

## The toolbox

One package-local wrapper, shown below as `<plx-engine>`. Each host skill defines how
to resolve it: Claude Code may invoke the packaged tool from `PATH`, while Codex uses
the installed plugin root explicitly. Follow the loaded skill's invocation form.

```
<plx-engine> --engine codex|grok|claude --mode ro|rw --repo <abs-path> \
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
| `reviewer-security`   | risk-triggered security review| `## Review brief`   |
| `kiss-reuse`          | existing-mechanism reuse      | `## KISS brief`     |
| `kiss-simplification` | complexity reduction          | `## KISS brief`     |
| `kiss-efficiency`     | unnecessary-work review       | `## KISS brief`     |
| `kiss-altitude`       | implementation-depth review   | `## KISS brief`     |
| `planner`             | architecture consulting       | `## Task brief`     |
| `plan-critic-implementation` | checkout/execution red-team | `## Draft plan` |
| `plan-critic-system`  | system/design red-team        | `## Draft plan`     |
| `worker`              | implementation (rw)           | `## Spec`           |

## Models

| model | how to call | default role |
| --- | --- | --- |
| gpt-5.6-sol | `--engine codex` (medium effort by default) | Claude-host plan/review judgment and `dev` implementation fallback |
| gpt-5.6-terra | `--engine codex --model gpt-5.6-terra --effort low` | doc-lookup web research lanes |
| grok-4.5 | `--engine grok` (medium effort by default) | `dev` implementation and standalone Build review |
| opus-4.8 | `--engine claude` | planning, review, or taste-heavy judgment when selected by the host config |
| host orchestrator | you — never delegated | plan authoring, standalone Build implementation, synthesis, targeted fixes, and final gate |

Models in the host package config are defaults, not restrictions. When the user
explicitly requests a model or effort, pass that exact value to the selected engine;
never silently substitute a configured default. Standalone plan critics otherwise
resolve from the host package config, and the loaded skill defines their model and
effort.

How to apply:

- **Defaults, not limits.** Start from the current host package's
  `config/parallax.yaml`. You have standing permission to override a binding if a cheaper
  model's output doesn't meet the bar: rerun the
  work on a smarter engine or higher effort without asking. Judge the output, not the
  price tag — escalating costs less than shipping mediocre work. This permission changes
  only model or effort; it never expands task scope, target resources, credentials,
  permissions, or allowed side effects.
- **Composed `dev` implementation prefers Grok 4.5 medium when available.** Probe it as optional before
  mutation. If that probe fails, require the configured `code-fallback` engine (Codex by
  default), declare the substitution, and use it for the whole writer turn. An explicit
  user engine override disables automatic fallback. Never fall back after a writer has
  started or after the worktree becomes dirty; stop and report the partial state.
- **Anything user-facing** (UI, copy, API design) may use Opus for a taste-focused
  advisory pass, while implementation remains on the configured Grok writer unless
  the reported fallback rule is triggered.
- **Reviews** → a capable model, plus optionally an independent perspective. Always prefer
  a *different* engine than the one that wrote the code — independence catches what
  self-review can't. Add `reviewer-security` when the user requests security review or
  the scope touches auth, permissions, secrets/config, shell or subprocess execution,
  sandboxing, network clients, dependencies/lockfiles, CI workflows, deserialization, or
  another trust boundary. Otherwise report `Security: not run`.
- **Targeted fixes from a review** → the host orchestrator applies them itself, as
  small scoped edits at the cited sites. It already holds the findings and the code
  context; a fix lane plus a verification pass of that lane's diff is wasted steps and
  compute. Fix only after every lane has returned; a build-sized remedy is not a
  targeted fix — send it back to a writer lane.
- **Effort**: Codex and Grok default to `medium`; Claude defaults to `high`. Escalate
  only for concrete complexity or risk. Reserve Codex `xhigh` for cross-file contracts,
  concurrency, data-integrity or money paths, wide refactors, and standalone plan
  critics. Grok supports only `low|medium|high`.
- **KISS** → exactly four read-only Grok `medium` dimensions: reuse, simplification,
  efficiency, and altitude. The current request may replace all lanes with one engine.
  The host synthesizes and applies the smallest safe improvements to a draft or code.
- **Doc-lookup research → Terra low.** When the task is finding official documentation
  and transcribing the facts (API shapes, config keys, version tables), run a read-only
  Codex lane with `--model gpt-5.6-terra --effort low`. On lookup work, effort buys
  latency, not accuracy — benchmarked 2026-07: Terra low matched Terra high fact-for-fact
  while running fastest of six contenders; Luna was slower at every effort tier. Reserve
  higher effort for research that needs synthesis or judgment, not retrieval.
- **Standalone Build is host-owned.** Given an accepted spec, the active host implements
  it directly, runs the three core Grok review dimensions, fixes confirmed findings,
  and executes the complete relevant verification suite. It has no writer lane and no
  fallback writer configuration.
- **The host orchestrator is never delegated.** Spend the main session where the loaded
  skill assigns ownership: plan authoring, standalone Build implementation, review
  synthesis, targeted fixes, and the final gate.

## Sizing the run (the escalation ladder)

For the composed `dev` pipeline, config bindings are the **floor shape**, not the ceiling or the mandate. Before
launching lanes, size the task and **declare the shape you chose in one line** (e.g.
`Sizing: implementation critic (<critic-engine>, high) · 1 worker (<writer-engine>, medium) · review 3×1
(<review-engine>, high)`) — it
gives the user a veto point before tokens burn. Scale down as readily as up.

| `dev` scale | plan | implementation | review |
| --- | --- | --- | --- |
| **trivial** — one file, obvious change | none — decide and go | one Grok rw lane | read the diff yourself |
| **small** — clear task, low blast radius | plan in-context, no critic | 1 worker | 1 lane (correctness only) |
| **default** | plan in-context + implementation and system critics | 1 configured worker | 3 dims × 1 opposite engine |
| **large / risky** | spec doc + both critics | parallel file-disjoint configured workers | 3 dims plus risk-triggered security × 1 opposite engine; add a second non-writer engine when proportionate |

The standalone plan skill preserves the full default plan rung: it resolves exactly one
engine for each critic dimension from the host package and runs both in
parallel. Explicit current-message substitutions win. Both required dimensions must
return before the plan is final. The full dev skill uses the same two-critic default as
part of the larger end-to-end run.

The standalone Build skill does not use this sizing ladder. Its ownership shape is
fixed: an accepted spec, direct host implementation, three read-only Grok review lanes
(plus security when triggered), host-applied confirmed fixes, and the complete relevant
verification suite. `dev` remains self-contained and does not invoke standalone Build.

The standalone review skill is a fixed-shape quality pipeline: direct invocation runs
correctness, cleanup, and structural lanes on Grok by default, plus a Grok security lane
when triggered. An explicit current-message `all <engine> lanes` substitution applies
to the whole round. The composed `dev` review stage keeps the opposite-host config
bindings and sizing ladder above.

KISS is a fixed four-lane quality pass for plans or code. An explicit current-message
`all <engine> lanes` substitution applies to the whole round.

Scale-up signals: cross-file contracts, concurrency, data-integrity or money paths,
wide refactors, high ambiguity, code you can't easily verify. Scale-down signals: one
file, an obvious mechanism, strong existing tests, a change you can read in one sitting.
Inside `dev`, the smallest rung skips advisory fanout, not implementation delegation:
even a trivial code change uses one configured rw lane, followed by host verification.

Plan artifacts follow the same logic: a plan is a chat message by default; write it to
`.project/builds/<thread>/` only when the effort is multi-session or another agent must
consume it later. A spec doc for a one-shot task is overhead, not rigor.

## Running lanes

- **Always use a retained/background shell session.** Engine turns can run 10–40+
  minutes. Launch with `--out <f> --log <f>`, fire independent lanes concurrently, and
  synthesize after completion. Results live on disk — read the out-files selectively;
  don't pull bulk content into your own window.
- **Grok may require narrowly scoped host approval** for network or keychain access;
  Grok's own kernel sandbox still confines it. The wrapper defaults the model to
  `grok-4.5` and effort to `medium`; explicit values pass through to Grok. A Grok writer
  must pass `plx-preflight --optional-grok --grok-mode rw` (or `--require-grok` for an
  explicit selection) before mutation; the workspace probe runs against a disposable
  directory rather than the target repository.
- **Pipeline-specific retry and completion rules override this general playbook.** If a lane
  fails (exit 1), read its log, then retry once — same engine, or a
  smarter one if the failure looks like capability. If a review lane fails and others
  succeeded, proceed with the survivors and say so; this survivor rule does not apply to
  required plan critics. **If a lane hangs** well past its
  expected runtime, check the log, kill it, and relaunch rather than waiting forever.
  The explicit single-engine passthrough skills are fail-closed exceptions: never redo
  their failed task in the host session or substitute another engine.
- Exit codes are uniform: 0 ok · 1 engine failure · 2 usage error · 3 not signed in
  (tell the user to log in to that engine).

## Writers

- **Within `dev`, one writer per disjoint path set.** Any number of parallel read-only lanes; rw lanes
  may run in parallel **only** when their file sets don't overlap — each writer's brief
  must name the paths it owns and state that other paths are being edited in parallel.
  Never edit a file yourself while a lane owns it. When in doubt, one writer.
- The sandboxes are repo-wide — path disjointness is brief discipline, not enforced.
  Split work only along genuinely independent seams; shared files (barrel exports,
  lockfiles, shared configs) mean the work is one package.
- **Verification runs after all writers land** — parallel test runs against half-built
  code in a shared worktree are noise.
