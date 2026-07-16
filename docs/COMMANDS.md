# Command surface

Both packages expose the same nine capabilities with platform-native invocation syntax.

| Capability | Claude Code | Codex | Behavior |
| --- | --- | --- | --- |
| Plan | `/plx:plan` | `$plx-plan` | Host authors; implementation and system critics red-team; no code |
| Build | `/plx:build` | `$plx-build` | One or more file-disjoint writer lanes implement and verify |
| Review | `/plx:review` | `$plx-review` | Sized read-only review, synthesis, and one targeted fix round |
| Dev | `/plx:dev` | `$plx-dev` | Plan → build → review/fix → final gate |
| Goal spec | `/plx:goal-spec` | `$plx-goal-spec` | Interview, planner, red-team, and autonomous-ready spec |
| Other host | `/plx:codex` | `$plx-claude` | One isolated opposite-engine passthrough |
| Grok | `/plx:grok` | `$plx-grok` | One isolated Grok 4.5 passthrough |
| Init | `/plx:init` | `$plx-init` | Bootstrap root `AGENTS.md`, `CLAUDE.md`, and `.project/` policy |
| Unknowns | `/plx:unknown-unknowns` | `$plx-unknown-unknowns` | Host-only blindspot and comprehension work |

Codex skills are explicit-only (`allow_implicit_invocation: false`) so an expensive
pipeline never starts merely because a prompt resembles its description.

Every pipeline reads its package-local `config/parallax.yaml`. Config is the floor shape,
not a limit: the host may scale lanes down or up and must declare the chosen shape before
launching. Skills never commit or publish; target-repository instructions govern Git.
