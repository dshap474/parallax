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
`PLX_TRACE_DB`). Do not add orchestration subagents, plugin-root traversal, repo-local
runtime state, hooks, telemetry services, or publishing behavior.

Codex skills use bare capability names (such as `plan`) and `agents/openai.yaml` with implicit invocation
disabled. Claude skills use `/plx:*` namespaced commands and explicit-only frontmatter
(`disable-model-invocation: true`, `user-invocable: true`). Equivalent capability does
not mean identical prose: preserve host-native tools and configured review polarity.
Config supplies engine bindings for `plan`, `simplify`, and `dev`; each
skill owns its shape and override rules. Standalone Review defines Grok defaults and
whole-round overrides in its skill. Keep composed review bindings under `dev`.

Keep pipeline full access confined to the single standalone Build worker. Codex
`danger-full-access` and Claude's sandbox-disabled permission bypass are transport
requirements for Git metadata and packaged review launches; they do not belong in review
lanes or expand task/publication authority. The standalone Devin passthrough separately
uses explicit full access and never joins a pipeline. Keep Codex's combined
approvals-and-sandbox bypass and `--yolo` prohibited.

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
small authenticated probe calls; when Grok is installed, this checks both its read-only
and disposable workspace sandbox profiles. The behavioral suite under `tests/smoke/`
spends more tokens and is opt-in.

Do not push, tag, open PRs, or publish unless the current user explicitly requests it.
