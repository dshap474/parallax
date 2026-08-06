# Parallax package specification

Status: v0.5.9

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

Both manifests use plugin name `plx` and version `0.5.9`. Both marketplaces use
`parallax-marketplace` and point to their platform package. Each package contains eleven
skills and no hooks, agents/subagents, MCP servers, apps, or repo-local runtime store.

## Package contracts

- Claude skill frontmatter uses the bare capability name, which Claude Code prefixes
  with the plugin namespace and exposes as `/plx:<name>`.
- Codex skill frontmatter uses the bare capability name, which the plugin namespace
  exposes as `$plx:<name>`; every skill has
  `agents/openai.yaml` with `allow_implicit_invocation: false`.
- The Codex opposite-host passthrough is `plx-claude`; the Claude opposite-host
  passthrough is `plx:codex`.
- Claude `/plx:codex` is ephemeral by default and may start or resume a persistent
  app-server thread only for explicit continuation or material multi-turn reuse. It
  returns the thread ID and keeps no Parallax thread registry.
- Claude-host defaults: Claude plans, synthesizes, and applies targeted fixes; Codex
  supplies plan critics and three core review dimensions plus risk-triggered security.
- Codex-host defaults: Codex plans, synthesizes, and applies targeted fixes; Claude
  supplies plan critics and three core review dimensions plus risk-triggered security.
- Standalone simplify always runs four read-only dimensions. It defaults to the opposite
  host engine; an explicit current-message whole-round engine request replaces all four
  bindings. The host applies only confirmed behavior-preserving fixes.
- Both hosts prefer Grok for initial implementation and use configured Codex fallback
  only when Grok fails an optional workspace-sandbox preflight before mutation. The
  workspace probe is confined to a disposable directory. Explicit engine selection
  disables fallback; a started or dirty writer never falls through to another engine,
  and an explicit Grok passthrough failure never falls through to host-session work.
- Shared runtime copies must exactly match `shared/`.

## Runtime contracts

Brief headers are `## Draft plan`, `## Task brief`, `## Review brief`,
`## Simplify brief`, or `## Spec`, matching the injected rubric. Advisory lanes are
read-only; writer lanes are scoped to the target repository and one disjoint path set.
Plans carry original request, confirmed decisions, candidate plan, and an observable
done condition.

No skill constructs a raw external-engine command. No wrapper uses forbidden broad
permission flags. Claude lanes ignore untrusted customization, do not persist sessions,
and fail closed if their sandbox is unavailable. Grok sandbox startup failures receive a
stable error marker and remain confined by the selected kernel profile. Temporary
artifacts are removed only through the confined cleanup helper. Skills never commit or
publish.
Persistent Codex access is passthrough-only and derives read or write scope for each
turn; every pipeline lane remains isolated and ephemeral.

Optional `PLX_TRACE_DB` collection writes local schema-v1 SQLite traces via `plx-eval`.
All eleven user-facing skills close a run; `plx-engine` captures complete prompts, traces,
outputs, and lane metadata, with grouped and standalone behavior. Recording failures
never change engine results. When the process variable is unset, a deterministic
non-executing parser reads the same literal assignment from the standard per-user
Parallax config file. No host hooks, telemetry service, MCP, or target-repo `.parallax/`
state.

## Acceptance

`bash tests/run.sh` must validate both manifests and marketplaces, version agreement,
eleven-skill inventories, platform frontmatter, engine polarity, simplify shape, fallback and security
bindings, executable wrappers, rubric resolution, shared-copy agreement, fake-engine
safety flags, cleanup confinement, optional eval
recorder contracts, and isolated `plx-link-claude` behavior. Official Claude and Codex
validators must also pass.
