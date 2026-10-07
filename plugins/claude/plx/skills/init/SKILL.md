---
name: init
description: Load a concise Parallax skill map and model defaults into the current context. No workflow is started.
argument-hint: ""
disable-model-invocation: true
user-invocable: true
---

# Parallax

Parallax provides these explicit skills. Init only loads this map; it runs nothing and
changes no files.

| Skill | Purpose |
| --- | --- |
| `/plx:plan` | The current host plans; Astra reviews. Produces a reviewed plan without coding. |
| `/plx:build` | One Opus 5.5 Medium worker implements and verifies the accepted plan. |
| `/plx:review` | Parallel GPT-6.1 Sol Medium lanes review correctness, cleanup, and structure; security when relevant. The host verifies findings and fixes confirmed issues. |
| `/plx:dev` | Runs Plan → Build → Review sequentially. |
| `/plx:simplify` | Four GPT-6.1 Sol Medium lanes suggest simplifications; the host applies confirmed improvements. |
| `/plx:kiss` | Loads KISS principles into context. |
| `/plx:orchestrate` | Loads a planner posture that delegates coding to native workers. |
| `/plx:unknown-unknowns` | Explores blind spots with the host. |
| `/plx:fanout-and-synthesize` | Host-led Sonnet High lanes by lens or shard, then one synthesis. |
| `/plx:adversarial-verification` | Sonnet High verifiers try to refute claims; the host keeps survivors. |
| `/plx:generate-and-filter` | Sonnet High lanes generate ideas and judge finalists pairwise; the host recommends one. |
| `/plx:codex`, `/plx:grok`, `/plx:gemini`, `/plx:devin` | Direct requests to another engine. |

For web research and documentation lookup, use Sonnet at low reasoning (`sonnet`, `low`) in a read-only lane.
Follow explicit user model choices. Recommend relevant skills; invoke them only when the
user asks. Briefly acknowledge that Parallax context is loaded.
