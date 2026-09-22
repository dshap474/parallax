# Parallax package specification

Status: v0.5.30

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

Both manifests use plugin name `plx` and version `0.5.30`. Both marketplaces use
`parallax-marketplace` and point to their platform package. Each package contains thirteen
skills and no hooks, agents/subagents, MCP servers, apps, or repo-local runtime store.

## Package contracts

- Claude skill frontmatter uses the bare capability name, which Claude Code prefixes
  with the plugin namespace and exposes as `/plx:<name>`; every skill is user-invocable
  and disables model-initiated invocation.
- Codex skill frontmatter uses the bare capability name, which the plugin namespace
  exposes as `$plx:<name>`; every skill has
  `agents/openai.yaml` with `allow_implicit_invocation: false`.
- The Codex opposite-host passthrough is `$plx:claude`; the Claude opposite-host
  passthrough is `plx:codex`.
- Both packages expose a standalone `devin` passthrough. It defaults to
  `swe-2-high`, accepts exact model overrides, rejects generic effort, and uses the
  explicit `full-access` wrapper mode without changing pipeline routing.
- Claude `/plx:codex` is ephemeral by default and may start or resume a persistent
  app-server thread only for explicit continuation or material multi-turn reuse. It
  returns the thread ID and keeps no Parallax thread registry.
- Claude-host Plan: Fable 5.1 authors and one GPT-6 Astra lane reviews.
- Codex-host Plan: GPT-6 Astra authors and one Fable 5.1 lane reviews.
- Build: one GPT-6 Sol High worker in Codex or Opus 5.5 Medium worker in Claude Code
  implements and verifies the accepted spec.
- Review: three Grok 4.5 Medium lanes run in parallel, with a security lane when
  triggered. The host verifies findings and applies confirmed fixes.
- Dev: Plan, Build, then Review run sequentially with those skill defaults.
- Simplify runs four read-only Grok 4.6 Medium dimensions over a plan or code. An explicit
  whole-round engine request replaces all four. The host applies only confirmed safe
  improvements.
- KISS is an explicit-only skill that loads the user-authored principles in its body into
  the current context. It launches no engine or runtime tooling.
- Standalone Build requires an accepted spec and delegates it to exactly one fresh
  same-host worker. There is no fallback or second writer. Build may
  create local commits required or authorized by the accepted spec or target-repository
  instructions, including ordered preregistration checkpoints, while staging only
  Build-owned work and preserving pre-existing changes.
- Web research and documentation lookup use GPT-6 Luna Max in Codex or Sonnet Low in
  Claude Code.
- Shared runtime copies must exactly match `shared/`.

## Runtime contracts

Brief headers are `## Draft plan`, `## Task brief`, `## Review brief`, `## Simplify brief`,
or `## Spec`, matching the injected rubric. Advisory lanes are read-only.
Plans carry original request, confirmed decisions, candidate plan, and an observable
done condition. Worker and host reports may use a compact natural format while retaining
scope, findings, decisions, and verification evidence. Review hosts may read code to
establish scope before sending the same neutral brief to every reviewer. Passthroughs
preserve engine exit status and cleanup without prescribing a tool-call count. Codex-hosted
Claude calls request host approval only when the host sandbox blocks required access.

No skill constructs a raw external-engine command. Codex lanes pin unattended approval
explicitly and never use the approvals-and-sandbox bypass or `--yolo`. Normal lanes use
read-only or workspace-constrained execution. The single standalone Build writer is the
deliberate exception: an `rw` `worker`/`build-worker` Codex or Claude lane receives full
host access for repository Git metadata and packaged review launches. That transport does
not expand task, target, external-system, or publication authority.

The standalone Devin passthrough is a separate deliberate full-access transport. It
uses dangerous permission mode without an OS sandbox, validates the exported terminal
ATIF response, stops its owned process group on interruption, and never retries or
falls back. The generated user config disables supported imports, updates, and
subagents; repository-native Devin hooks, MCP servers, rules, and skills may still load.
The effective prompt lists ignored, untracked, and nested repository guidance. Questions,
plans, and reviews carry an explicit no-edit instruction, but this is not enforced by a
sandbox. External actions still require exact user authorization.

Claude lanes ignore ambient customization, do not persist sessions, and fail closed if
their normal sandbox is unavailable. Because safe mode disables instruction discovery,
the wrapper lists physical source-tree guidance, including ignored, untracked, symlinked,
and path-scoped rule files while excluding common dependency/cache trees. Grok uses
unattended tool approval with a separate explicit filesystem sandbox; current snake-case
stop reasons are handled, and sandbox startup failures receive a stable error marker.
Temporary artifacts are removed only through the confined cleanup helper. Standalone
Build follows the repository-governed local-commit contract above. No skill performs
remote Git, deployment, release, or external publication without separate authority;
target-local artifacts required by an accepted spec are allowed.
Persistent Codex access is passthrough-only and derives read or write scope for each
turn; every pipeline lane remains isolated and ephemeral.

Optional `PLX_TRACE_DB` collection writes local schema-v2 SQLite traces via `plx-eval`
and migrates version 1 databases in place. Operational skills close a run;
the context-only Init, KISS, and Orchestrate skills do not. `plx-engine` captures
complete prompts, traces, outputs, and lane metadata, with
grouped and standalone behavior. Recording failures never change engine results. When
the process variable is unset, a deterministic
non-executing parser reads the same literal assignment from the standard per-user
Parallax config file. No host hooks, telemetry service, MCP, or target-repo `.parallax/`
state.

## Acceptance

`bash tests/run.sh` must validate both manifests and marketplaces, version agreement,
thirteen-skill inventories, explicit-only platform metadata, engine polarity, Simplify
shape, the context-only skill contracts, Plan/Build/Review routing and security triggers,
executable wrappers,
rubric resolution, shared-copy agreement, fake-engine safety flags and current result
envelopes, cleanup confinement, optional eval recorder contracts, and isolated
`plx-link-claude` behavior. Official Claude and Codex validators must also pass.

## Gemini engine

Both packages expose a standalone `gemini` passthrough through `plx-engine`.
It defaults to `auto`, accepts `--model`, rejects `--effort`, and supports `ro`
read tools or `rw` file-edit tools with a required sandbox. Shell execution,
extensions, MCP, and hooks are disabled. Existing pipeline defaults are unchanged.
