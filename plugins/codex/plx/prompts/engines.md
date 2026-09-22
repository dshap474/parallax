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
| `plan-critic` | plan feasibility and design review | `## Draft plan` |
| `worker` | general implementation | `## Spec` |
| `build-worker` | Build: implement and verify | `## Spec` |
| `reviewer-correctness` | behavioral-defect review | `## Review brief` |
| `reviewer-cleanup` | reuse and simplification review | `## Review brief` |
| `reviewer-structural` | maintainability review | `## Review brief` |
| `reviewer-security` | risk-triggered security review | `## Review brief` |
| `simplify-reuse` | existing-mechanism reuse | `## Simplify brief` |
| `simplify-simplification` | complexity reduction | `## Simplify brief` |
| `simplify-efficiency` | unnecessary-work review | `## Simplify brief` |
| `simplify-altitude` | implementation-depth review | `## Simplify brief` |

## Defaults and routing

Plan, Build, and Review define their model defaults in their skills. Dev follows
Plan -> Build -> Review sequentially. Build performs implementation and verification;
Review owns the parallel review lanes and host-applied fixes. Only Simplify reads
engine bindings from package config. The wrapper's generic defaults do not override
explicit model flags supplied by a skill.

An explicit current-message model or effort request
wins, except `grok-4.6` always runs at medium and retired Opus 5 and GPT-5.6 Sol/Luna
IDs are rejected. The unpinned `opus` and `gpt-5.6` aliases are also rejected.
Follow the selected skill on failure; do not silently substitute another model.

Current explicit model choices include Claude `claude-opus-5-5` for long-running
coding and knowledge work, Codex `gpt-6-sol` for complex coding, and Codex
`gpt-6-luna` for focused tasks. Pass these exact IDs with `--model`; provider and
account availability still determine whether a call succeeds. See the
[Claude model list](https://platform.claude.com/docs/en/models/overview) and
[Codex model list](https://learn.chatgpt.com/docs/models) for current availability.

- Add the security lane when requested or when changes touch auth, permissions, secrets,
  shell/subprocess execution, sandboxing, network clients, dependencies, CI,
  deserialization, or another trust boundary. Otherwise report `Security: not run`.
- Simplify always runs reuse, simplification, efficiency, and altitude on Grok 4.6 Medium,
  unless the current request replaces the whole round with one engine.
- Official-document lookup defaults to Terra low. Use higher effort only when the work
  needs synthesis or judgment, not simple retrieval.
- Apply confirmed, small review fixes in the host after all lanes return. A build-sized or
  behavior-changing remedy needs a writer or user decision.

## Build transport

Build uses one same-host worker for implementation and verification. This worker may
use full access for Git metadata: Codex `danger-full-access`, or Claude with its sandbox
and permission prompts disabled. The wrapper accepts this only for an `rw`
`worker`/`build-worker` rubric. It does not expand scope or publication authority.
Review lanes stay read-only. Never use Codex `--dangerously-bypass-approvals-and-sandbox`
or `--yolo`.

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

## Gemini passthrough

`gemini` defaults to `auto` model routing and accepts an explicit `--model`, but no
`--effort`. It exposes read tools in `ro` and file-edit tools in `rw`; shell execution,
MCP, extensions, and hooks are disabled. macOS Seatbelt sandbox startup is required. The standalone `gemini` skill does not change pipeline defaults.
