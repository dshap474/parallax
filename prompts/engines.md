# Engines — the Parallax toolbox and how to choose

Parallax gives the orchestrator **tools, not a script**: three coding engines, each
drivable headless through one wrapper, plus a set of lane rubrics. You decide which
engines to use for which work; this doc carries the judgment.

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
| `plan-critic`         | plan red-team                 | `## Draft plan`     |
| `worker`              | implementation (rw mode)      | `## Spec`           |

## Running lanes

- **Always background Bash.** Engine turns can run 10–40+ minutes; foreground Bash caps
  at 10. Launch with `run_in_background` and `--out <f> --log <f>`, fire independent
  lanes in one message so they run concurrently, and synthesize when the harness reports
  completion. Results live on disk — read the out-files selectively; don't pull bulk
  content into your own window.
- **Grok calls need the Bash sandbox disabled** for the call
  (`dangerouslyDisableSandbox: true`) — grok needs network/keychain access the sandbox
  blocks; grok's own kernel sandbox still confines it.
- Exit codes are uniform: 0 ok · 1 engine failure · 2 usage error · 3 not signed in
  (tell the user to log in to that engine).

## Engine characteristics

| engine | via                | strengths                                             | notes |
| ------ | ------------------ | ----------------------------------------------------- | ----- |
| codex  | `codex exec`       | strong correctness reviewer; cheap bulk implementation | effort `low`–`xhigh`; no session resume (`--ephemeral`) |
| grok   | `grok` headless    | fast, cheap second perspective                         | kernel-sandboxed; no model/effort knobs |
| claude | `claude -p`        | deepest reasoning and taste; best for hard design, ambiguous specs, user-facing quality | effort via `--effort`; slower startup (loads project context) |

## How to choose (defaults, not limits)

- **Judge the output, not the price tag.** These are defaults; you have standing
  permission to rerun weak output on a smarter engine or higher effort without asking.
  Escalating costs less than shipping mediocre work.
- **Cross-engine review.** Review work with a *different* engine than the one that wrote
  it — independence catches what self-review can't. Add a second reviewer engine when
  the change is high-risk (contracts, concurrency, data integrity, money paths).
- **Bulk or mechanical work** (clear-spec implementation, migrations, data analysis) goes
  to the cheaper engines; **anything that ships user-facing quality** (API design, UI,
  copy, hard architecture) goes to the engine with the most taste, or stays with you.
- **Effort**: `high` is the default for reviews and builds; reserve `xhigh` for
  cross-file contract changes, concurrency, data-integrity or wide-refactor risk.
- **One writer at a time, always.** Any number of parallel read-only lanes; exactly one
  rw lane, and never rw while you are editing the same files yourself.
