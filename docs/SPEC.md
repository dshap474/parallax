# Parallax package specification

Status: v0.5.3

## Required tree

```text
.claude-plugin/marketplace.json
.agents/plugins/marketplace.json
plugins/claude/plx/.claude-plugin/plugin.json
plugins/codex/plx/.codex-plugin/plugin.json
plugins/{claude,codex}/plx/{skills,config,bin,prompts}/
plugins/claude/plx/tools/codex-app-client/
shared/{bin,prompts}/
scripts/sync-shared.sh
```

Both manifests use plugin name `plx` and version `0.5.3`. Both marketplaces use
`parallax-marketplace` and point to their platform package. Each package contains nine
skills and no hooks, agents/subagents, MCP servers, apps, or repo-local runtime store.

## Package contracts

- Claude skill paths map to `/plx:<name>` and use the Claude package config.
- Codex skill frontmatter uses the bare capability name, which the plugin namespace
  exposes as `$plx:<name>`; every skill has
  `agents/openai.yaml` with `allow_implicit_invocation: false`.
- The Codex opposite-host passthrough is `plx-claude`; the Claude opposite-host
  passthrough is `plx:codex`.
- Claude `/plx:codex` is ephemeral by default and may start or resume a persistent
  app-server thread only for explicit continuation or material multi-turn reuse. It
  returns the thread ID and keeps no Parallax thread registry.
- Claude-host defaults: Claude plans and synthesizes; Codex supplies plan critics and
  all three review dimensions; Grok writes and fixes.
- Codex-host defaults: Codex plans and synthesizes; Claude supplies plan critics and
  all three review dimensions; Grok writes and fixes.
- Shared runtime copies must exactly match `shared/`.

## Runtime contracts

Brief headers are `## Draft plan`, `## Task brief`, `## Review brief`, or `## Spec`,
matching the injected rubric. Advisory lanes are read-only; writer lanes are scoped to
the target repository and one disjoint path set. Plans carry original request, confirmed
decisions, candidate plan, and an observable done condition.

No skill constructs a raw external-engine command. No wrapper uses forbidden broad
permission flags. Temporary artifacts are cleaned up. Skills never commit or publish.
Persistent Codex access is passthrough-only and derives read or write scope for each
turn; every pipeline lane remains isolated and ephemeral.

## Acceptance

`bash tests/run.sh` must validate both manifests and marketplaces, version agreement,
nine-skill inventories, platform frontmatter, engine polarity, executable wrappers,
rubric resolution, shared-copy agreement, fake-engine safety flags, and isolated
`plx-link-claude` behavior. Official Claude and Codex validators must also pass.
