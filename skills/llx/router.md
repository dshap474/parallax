# Parallax LLX Router

The user invoked `/parallax:llx`.

Your job is to choose the smallest workflow that gives enough assurance. This file owns mode selection and preflight policy only; `modes.md` owns executable workflow steps.

## Inputs

Use:

1. User request from `SKILL.md`.
2. Deterministic intake output.
3. Current repo state.
4. Available engines from preflight.
5. Existing project guidance: `AGENTS.md`, `CLAUDE.md`, README, package files, tests.

## Mode selection

Choose one mode.

### `quick`

Use when all are true:

- one-file or very small change
- low-risk
- no architecture change
- no unclear spec
- no external model review needed
- user did not ask for multi-model review

Do not call Codex or Grok.

### `team`

Default mode.

Use when task is substantial but ordinary:

- feature
- refactor
- bug fix with nontrivial surface
- rewrite with clear scope
- user asks to build something

Use Codex required. Grok not required.

### `panel`

Use when task is substantial and would benefit from extra review, but does not need full ultra plan panel:

- risky feature
- broad refactor
- ambiguous implementation
- public API change
- concurrency, state, persistence, auth, money, trading, crypto, or data-loss risk
- user asks for more scrutiny
- Grok is available

Use Grok only if available. If Grok absent, degrade to `team` and say so.

### `ultra`

Use only when task is high-stakes or structurally large:

- major architecture change
- multi-module rewrite
- migration
- security-sensitive implementation
- financial/trading-critical logic
- correctness-critical algorithm
- user explicitly asks for max effort / ultra / full panel

Requires Codex. Requires Grok unless user accepts degradation. If Grok absent, degrade to `panel` or `team`.

### `review-only`

Use when user asks to review, audit, critique, debug, inspect, or assess existing code without requesting edits.

Do not edit files unless user explicitly approves fixes.

## Preflight policy

After choosing a candidate mode:

- `quick`: no external preflight needed.
- `team`: run `${CLAUDE_SKILL_DIR}/scripts/preflight.sh --run-dir <run-dir> --require-codex`.
- `panel`: run `${CLAUDE_SKILL_DIR}/scripts/preflight.sh --run-dir <run-dir> --require-codex --optional-grok`.
- `ultra`: run `${CLAUDE_SKILL_DIR}/scripts/preflight.sh --run-dir <run-dir> --require-codex --require-grok`.
- `review-only`: run preflight with `--run-dir <run-dir>` only for the engines needed by the selected review lanes.

If a required engine is unavailable, stop with a clear message.
If an optional engine is unavailable, drop that lane and continue.

`<run-dir>` is the absolute run directory printed by deterministic intake.

## Output discipline

At the start of execution, state:

```text
Selected mode: <mode>
Reason: <one sentence>
Run dir: <path>
```

At the end, report:

```text
Built:
Plan changes:
Refine changes:
Review findings:
Fixes applied:
Verification:
Residual risk:
```
