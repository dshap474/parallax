# Parallax package specification

Status: v0.5.36

## Required tree

```text
.claude-plugin/marketplace.json
.agents/plugins/marketplace.json
plugins/claude/plx/.claude-plugin/plugin.json
plugins/codex/plx/.codex-plugin/plugin.json
plugins/{claude,codex}/plx/{skills,bin,prompts}/
shared/{bin,prompts}/
scripts/sync-shared.sh
```

Both manifests use plugin name `plx` and version `0.5.36`. Both marketplaces use
`parallax-marketplace` and point to their platform package. Each package contains sixteen
skills and no hooks, agents/subagents, MCP servers, apps, or repo-local runtime store.

## Package contracts

- Claude skill frontmatter uses the bare capability name, which Claude Code prefixes
  with the plugin namespace and exposes as `/plx:<name>`; every skill is user-invocable
  and disables model-initiated invocation.
- Codex skill frontmatter uses the bare capability name, which the plugin namespace
  exposes as `$plx:<name>`; every skill has
  `agents/openai.yaml` with `allow_implicit_invocation: false`.
- The Codex opposite-host passthrough is `$plx:claude`; the Claude opposite-host
  passthrough is `/plx:codex`.
- Skill model defaults and routing are listed in [Commands](COMMANDS.md); runtime
  safety and Git rules are in [Architecture](ARCHITECTURE.md#runtime-and-safety).
- Shared runtime copies must exactly match `shared/`.

## Runtime contracts

Brief headers are `## Draft plan`, `## Review brief`, `## Simplify brief`, or `## Spec`,
matching the injected rubric. Plans carry the original request, confirmed decisions,
candidate plan, and an observable done condition. Review hosts may read code to
establish scope before sending the same neutral brief to every reviewer. No skill
constructs a raw external-engine command.

## Acceptance

`bash tests/run.sh` must validate both manifests and marketplaces, version agreement,
sixteen-skill inventories, explicit-only platform metadata, engine polarity, Simplify
shape, the context-only skill contracts, Plan/Build/Review routing and security triggers,
executable wrappers, rubric resolution, shared-copy agreement, fake-engine safety flags
and current result envelopes, and cleanup confinement. The official Claude validator and an isolated Codex CLI
install with exact source/cache comparison must also pass.
