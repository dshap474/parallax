# Parallax PLX Router

The user invoked `/parallax:plx`.

Your job is to choose the smallest workflow that gives enough assurance. This file owns mode selection and preflight policy only; `modes.md` owns executable workflow steps.

## Inputs

Use:

1. User request from `SKILL.md`.
2. Deterministic intake output.
3. Current repo state.
4. Available engines (resolved by preflight, which runs *after* you pick a candidate mode — see Preflight policy; use it to confirm or degrade, not as a precondition for mode choice).
5. Engine-per-role config in `${CLAUDE_SKILL_DIR}/parallax.yaml` (which engines the chosen mode will use).
6. Existing project guidance: `AGENTS.md`, `CLAUDE.md`, README, package files, tests.

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

Preflight requirements follow the **engines actually used by the selected mode in `parallax.yaml`**, not a fixed per-mode list. The lines below are the defaults; if the config changes which engines a mode uses, adjust the flags to match (require the writer engine and any required review engine; make optional engines optional). The same CLI/auth backs an engine's `-ro` and `-rw` wrappers, so the read-only probe is a sufficient availability check for a non-Claude writer.

After choosing a candidate mode (default-config flags shown):

- `quick`: no external preflight needed (unless the config sets a non-Claude `code` writer — then require that engine).
- `team`: run `${CLAUDE_SKILL_DIR}/scripts/preflight.sh --repo <repo> --require-codex`.
- `panel`: run `${CLAUDE_SKILL_DIR}/scripts/preflight.sh --repo <repo> --require-codex --optional-grok`.
- `ultra`: run `${CLAUDE_SKILL_DIR}/scripts/preflight.sh --repo <repo> --require-codex --require-grok`.
- `review-only`: run preflight with `--repo <repo>` only for the engines needed by the selected review lanes.

If a required engine is unavailable, stop with a clear message.
If an optional engine is unavailable, drop that lane and continue.

`<repo>` is the absolute repo path printed by deterministic intake.

## Output discipline

At the start of execution, state:

```text
Selected mode: <mode>
Reason: <one sentence>
Repo: <path>
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
