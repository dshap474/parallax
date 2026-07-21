# Contributing

Parallax is a dual-plugin monorepo. Keep changes narrow and preserve each installable
package as a complete cache-safe unit.

## Where changes belong

- Edit shared engine execution in `shared/bin/`.
- Edit shared lane judgment in `shared/prompts/`.
- Run `scripts/sync-shared.sh` after either change; never hand-edit generated copies.
- Edit host-native skills and configs under `plugins/claude/plx/` or
  `plugins/codex/plx/`.
- Keep the Claude marketplace in `.claude-plugin/marketplace.json` and the Codex
  marketplace in `.agents/plugins/marketplace.json`.

Skills carry their complete pipeline inline. Rubric text shared across runs stays in
`prompts/` and is injected by bare rubric name. External engine execution belongs only
in `plx-engine`. Optional evaluation provenance belongs in `plx-eval` (opt-in via
`PLX_EVAL_DIR`). Do not add orchestration subagents, plugin-root traversal, repo-local
runtime state, hooks, telemetry services, or publishing behavior.

Codex skills use plain `plx-*` names and `agents/openai.yaml` with implicit invocation
disabled. Claude skills use `/plx:*` namespaced commands. Equivalent capability does not
mean identical prose: preserve host-native tools and the configured review polarity.

## Verification

```bash
scripts/sync-shared.sh --check
bash tests/run.sh
claude plugin validate .
claude plugin validate plugins/claude/plx
uv run --with pyyaml python \
  ~/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py plugins/codex/plx
```

`tests/run.sh` is model-free by default. Pass `--with-engines` deliberately to spend
small authenticated probe calls. The behavioral suite under `tests/smoke/` spends more
tokens and is opt-in.

Do not push, tag, open PRs, or publish unless the current user explicitly requests it.
