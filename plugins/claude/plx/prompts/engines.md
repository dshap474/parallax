# Engines — Parallax routing guide

Parallax gives the host headless engines and focused lane rubrics. Choose the
smallest shape that can deliver a verified outcome. Skills define workflow ownership;
this guide defines routing, safety, and scaling.

## Engine API

Use the package-local wrapper exactly as the loaded skill specifies:

```text
<plx-engine> --engine codex|grok|claude|gemini --mode ro|rw --repo <abs-path> \
  --prompt-file <brief> [--rubric <name>] [--model <model>] [--effort <level>] \
  (--stdout | --out <file> --log <file>)
```

Never hand-build raw engine commands or paste rubric text into briefs. The wrapper pins
non-interactive execution, approval policy, sandbox selection, and session behavior.
Codex ignores user config but may still load other documented configuration layers.

Write briefs in plain language with only what the lane needs:

- outcome;
- relevant context and evidence sources;
- hard scope and authority boundaries;
- observable success checks; and
- required output shape.

Let the model choose local implementation steps unless their sequence is part of the
contract. State each rule once.

| Rubric | Outcome | Brief header |
| --- | --- | --- |
| `planner` | architecture recommendation | `## Task brief` |
| `plan-critic-implementation` | execution red-team | `## Draft plan` |
| `plan-critic-system` | system/design red-team | `## Draft plan` |
| `worker` | `dev` implementation | `## Spec` |
| `build-worker` | standalone Build: implement, review, fix, verify | `## Spec` |
| `reviewer-correctness` | behavioral-defect review | `## Review brief` |
| `reviewer-cleanup` | reuse and simplification review | `## Review brief` |
| `reviewer-structural` | maintainability review | `## Review brief` |
| `reviewer-security` | risk-triggered security review | `## Review brief` |
| `simplify-reuse` | existing-mechanism reuse | `## Simplify brief` |
| `simplify-simplification` | complexity reduction | `## Simplify brief` |
| `simplify-efficiency` | unnecessary-work review | `## Simplify brief` |
| `simplify-altitude` | implementation-depth review | `## Simplify brief` |

## Defaults and routing

| Model | Default role |
| --- | --- |
| Codex `gpt-6-sol` | plan/review judgment and `dev` fallback |
| Codex `gpt-5.6-terra` low | official-document lookup |
| Grok `grok-4.6` medium | `dev` implementation and Grok review lanes |
| Claude `claude-opus-5-5` | planning, review, and taste-heavy judgment |
| Host orchestrator | plan authorship, synthesis, targeted fixes, and final gate |

Package config supplies defaults. An explicit current-message model or effort request
wins, except `grok-4.6` always runs at medium and retired Opus 5 and GPT-5.6 Sol/Luna
IDs are rejected. The unpinned `opus` and `gpt-5.6` aliases are also rejected.
Escalate model or effort when the first result is materially inadequate; this never
expands scope or authority.

Current explicit model choices include Claude `claude-opus-5-5` for long-running
coding and knowledge work, Codex `gpt-6-sol` for complex coding, and Codex
`gpt-6-luna` for focused tasks. Pass these exact IDs with `--model`; provider and
account availability still determine whether a call succeeds. See the
[Claude model list](https://platform.claude.com/docs/en/models/overview) and
[Codex model list](https://learn.chatgpt.com/docs/models) for current availability.

- `dev` prefers Grok 4.6 medium for implementation. Probe its workspace sandbox before
  mutation. If optional preflight fails, use the configured Codex fallback for the whole
  writer turn and report the substitution. Explicit engine selection disables fallback.
  Never switch writers after mutation starts or the worktree becomes dirty.
- Plan critics and composed `dev` reviewers use the opposite engine from the host as
  defined by package config. Direct Review instead runs the three core Grok 4.6 Medium
  lanes by default.
- Add the security lane when requested or when changes touch auth, permissions, secrets,
  shell/subprocess execution, sandboxing, network clients, dependencies, CI,
  deserialization, or another trust boundary. Otherwise report `Security: not run`.
- Simplify always runs reuse, simplification, efficiency, and altitude on Grok 4.6 Medium,
  unless the current request replaces the whole round with one engine.
- Official-document lookup defaults to Terra low. Use higher effort only when the work
  needs synthesis or judgment, not simple retrieval.
- Apply confirmed, small review fixes in the host after all lanes return. A build-sized or
  behavior-changing remedy needs a writer or user decision.

## Standalone Build

Build has a fixed shape and does not use the `dev` sizing ladder. One fresh same-host
worker receives the accepted spec:

- Codex host: `gpt-6-sol` high;
- Claude host: `claude-opus-5-5` medium.

That worker implements, launches three read-only Grok 4.6 Medium review lanes, validates
and fixes confirmed findings once, and runs the complete relevant verification suite.
The host only bootstraps, gate-checks, records, and reports. There is no fallback, second
writer, or parallel host implementation.

This worker is the sole full-access lane. Codex uses `danger-full-access`; Claude disables
its sandbox and permission prompts. The wrapper accepts this only for an `rw`
`worker`/`build-worker` rubric. Full access permits repository Git metadata and packaged
review launches; it does not expand the accepted spec, repository scope, publication
authority, or external-system authority. Review lanes remain read-only. Never use Codex
`--dangerously-bypass-approvals-and-sandbox` or `--yolo`.

## Size composed `dev`

Declare the chosen shape before launching lanes. Scale down as readily as up.

| Scale | Plan | Implementation | Review |
| --- | --- | --- | --- |
| trivial | host decision | one configured writer | host reads diff and verifies |
| small | in-context plan | one writer | correctness lane |
| default | implementation + system critics | one writer | three opposite-engine dimensions |
| large/risky | persisted spec + both critics | file-disjoint writers only when safe | core dimensions + security when triggered; add a second perspective when proportionate |

Use the larger shapes for cross-file contracts, concurrency, data integrity, money paths,
wide refactors, high ambiguity, or hard-to-verify behavior. Use the smaller shapes for an
obvious, low-blast-radius change with strong existing tests. Even a trivial `dev` code
change keeps one configured writer; it skips advisory fanout, not implementation
delegation.

Plans stay in conversation unless another session or worker needs a durable artifact.

## Run and failure rules

- Long lanes run in retained/background shells with `--out` and `--log`. Launch
  independent read-only lanes concurrently and read their output files after completion.
- Exit codes: 0 success; 1 engine failure; 2 usage error; 3 authentication required.
- Follow the loaded skill's retry rule. General advisory lanes may retry once, then
  continue with survivors and disclose the missing lane. Required plan critics and
  explicit passthrough skills fail closed.
- If a lane stalls beyond a reasonable runtime, inspect its log, stop it, and relaunch
  according to the skill instead of waiting indefinitely.
- Grok permission bypass auto-approves tools but does not disable its selected filesystem
  sandbox. A workspace-sandbox startup failure never authorizes host substitution.

## Writer discipline

Within `dev`, assign one writer per genuinely disjoint path set. Briefs name owned paths
and concurrent edits. Shared files, lockfiles, exports, and configs usually make the work
one writer's job. The sandbox is repo-wide, so ownership is a workflow contract rather
than an enforced path boundary. Run verification only after all writers finish.

## Gemini passthrough

`gemini` defaults to `auto` model routing and accepts an explicit `--model`, but no
`--effort`. It exposes read tools in `ro` and file-edit tools in `rw`; shell execution,
MCP, extensions, and hooks are disabled. macOS Seatbelt sandbox startup is required. The standalone `gemini` skill does not change pipeline defaults.
