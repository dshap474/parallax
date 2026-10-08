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
in `plx-engine`. Do not add subagent orchestration to operational pipelines; the
host-led `orchestrate`, `fanout-and-synthesize`, `adversarial-verification`, and
`generate-and-filter` skills are the explicit exceptions. Do not add plugin-root
traversal, repo-local runtime state, hooks, telemetry services, or publishing behavior.

Codex skills use bare capability names (such as `plan`) and `agents/openai.yaml` with implicit invocation
disabled. Claude skills use `/plx:*` namespaced commands and explicit-only frontmatter
(`disable-model-invocation: true`, `user-invocable: true`). Equivalent capability does
not mean identical prose: preserve host-native tools and Plan review polarity.
Each skill defines its own model defaults. Keep full host access to the three paths
listed in [Architecture](ARCHITECTURE.md#runtime-and-safety), and keep Codex's combined
approvals-and-sandbox bypass and `--yolo` prohibited.

## Verification

```bash
scripts/sync-shared.sh --check
bash tests/run.sh
claude plugin validate .
claude plugin validate plugins/claude/plx
```

`tests/run.sh` is model-free. The behavioral suite under `tests/smoke/`
spends more tokens and is opt-in.
The local release skill validates the Codex package by installing it with the Codex CLI
inside a temporary `CODEX_HOME` and comparing the cache byte-for-byte with source.

Do not push, tag, open PRs, or publish unless the current user explicitly requests it.
