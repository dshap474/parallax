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

## Models

| model | how to call | default role |
| --- | --- | --- |
| gpt-5.6-sol | `--engine codex` (medium effort by default) | default implementation, fixes, and Codex review lanes |
| grok-4.5 | `--engine grok` (medium effort by default) | implementation alternative and independent review perspective |
| opus-4.8 | `--engine claude` | optional planning, review, or taste-heavy judgment |
| fable-5 | you — the orchestrator; never delegated | plan authoring, synthesis, and final gate |

GPT-5.5 and Sonnet are forbidden. Do not select them even when explicitly requested as
an engine substitution; `plx-engine` rejects both. Standalone Codex plan critics keep
their deliberate `gpt-5.6-sol` at `xhigh` binding.

How to apply:

- **Defaults, not limits.** You have standing permission to override any binding in
  `config/parallax.yaml`: if a cheaper model's output doesn't meet the bar, rerun the
  work on a smarter engine or higher effort without asking. Judge the output, not the
  price tag — escalating costs less than shipping mediocre work. This permission changes
  only model or effort; it never expands task scope, target resources, credentials,
  permissions, allowed side effects, or the forbidden-model rule.
- **Implementation starts with GPT-5.6 Sol medium or Grok 4.5 medium.** Prefer Sol for
  complex code reasoning and cross-file precision. Prefer Grok for clear mechanical
  work or an independent implementation perspective. The shipped scalar binding is
  Codex; choosing Grok needs no user confirmation.
- **Anything user-facing** (UI, copy, API design) may use Opus for a taste-focused
  advisory pass, while implementation remains Sol or Grok.
- **Reviews** → a capable model, plus optionally an independent perspective. Always prefer
  a *different* engine than the one that wrote the code — independence catches what
  self-review can't.
- **Targeted fixes from a review** → fast and cheap (Grok 4.5 at low/medium, or codex at
  `--effort medium`) — small scoped fixes don't need taste.
- **Effort**: Codex and Grok default to `medium`; Claude defaults to `high`. Escalate
  only for concrete complexity or risk. Reserve Codex `xhigh` for cross-file contracts,
  concurrency, data-integrity or money paths, wide refactors, and standalone plan
  critics. Grok supports only `low|medium|high`.
- **The host orchestrator is never delegated.** Spend the main session where judgment
  is the product (plan authoring, review synthesis, the final gate), not on bulk reads
  or mechanical edits.

## Sizing the run (the escalation ladder)

Config bindings are the **floor shape**, not the ceiling or the mandate. Before
launching lanes, size the task and **declare the shape you chose in one line** (e.g.
`Sizing: implementation critic (codex, high) · 1 worker (codex, medium) · review 3×1
(grok, high)`) — it
gives the user a veto point before tokens burn. Scale down as readily as up.

| scale | plan | build | review |
| --- | --- | --- | --- |
| **trivial** — one file, obvious change | none — decide and go | edit it yourself, or one rw lane | read the diff yourself |
| **small** — clear task, low blast radius | plan in-context, no critic | 1 worker | 1 lane (correctness only) |
| **default** | plan in-context + implementation critic | 1 worker | 3 dims × 1 engine |
| **large / risky** | spec doc + implementation and system critics | parallel file-disjoint workers | 3 dims × 2 engines, xhigh |

The standalone plan skill deliberately overrides the default plan rung: it resolves
exactly one engine for each critic dimension from the host package and runs both in
parallel. Explicit current-message substitutions win. Both required dimensions must
return before the plan is final. The full dev skill keeps the proportional sizing above
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

- **Always use a retained/background shell session.** Engine turns can run 10–40+
  minutes. Launch with `--out <f> --log <f>`, fire independent lanes concurrently, and
  synthesize after completion. Results live on disk — read the out-files selectively;
  don't pull bulk content into your own window.
- **Grok may require narrowly scoped host approval** for network or keychain access;
  Grok's own kernel sandbox still confines it. The wrapper fixes the model to `grok-4.5`,
  defaults effort to `medium`, and accepts explicit `low|medium|high`.
- **Pipeline-specific retry and completion rules override this general playbook.** If a lane
  fails (exit 1), read its log, then retry once — same engine, or a
  smarter one if the failure looks like capability. If a review lane fails and others
  succeeded, proceed with the survivors and say so; this survivor rule does not apply to
  required plan critics. **If a lane hangs** well past its
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
