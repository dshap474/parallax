---
name: init
description: Load a concise Parallax skill map and model defaults into the current context. No workflow is started.
argument-hint: ""
disable-model-invocation: true
user-invocable: true
---

# Parallax

Parallax provides these explicit skills. Init only adds this information to context;
it does not run commands, launch workers, record a run, or change files.

| Skill | Purpose |
| --- | --- |
| `/plx:plan` | The current host plans; Astra reviews. Produces a reviewed plan without coding. |
| `/plx:build` | One Opus 5.5 Medium worker implements and verifies the accepted plan. |
| `/plx:review` | Parallel Grok 4.5 Medium lanes review correctness, cleanup, and structure; security when relevant. The host verifies findings and fixes confirmed issues. |
| `/plx:dev` | Runs Plan → Build → Review sequentially. |
| `/plx:simplify` | Four Grok 4.6 Medium lanes suggest simplifications; the host applies confirmed improvements. |
| `/plx:kiss` | Loads KISS principles into context. |
| `/plx:orchestrate` | Loads a planner posture that delegates coding to native workers. |
| `/plx:unknown-unknowns` | Explores blind spots with the host. |
| `/plx:codex`, `/plx:grok`, `/plx:gemini`, `/plx:devin` | Direct requests to another engine. |

For web research and documentation lookup, use Sonnet at low reasoning (`sonnet`, `low`) in a read-only lane.
Skills own their execution instructions and use Parallax's packaged engine tools.
Follow explicit user model choices. Recommend relevant skills; invoke them when the user
requests them or as part of the Dev sequence. Briefly acknowledge that Parallax context is loaded.
