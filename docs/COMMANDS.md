# Command surface

Both packages expose the same core capabilities with platform-native invocation syntax.

| Capability | Claude Code | Codex | Behavior |
| --- | --- | --- | --- |
| Plan | `/plx:plan` | `$plx:plan` | Host authors; one opposite-host reviewer checks the plan; no code |
| Build | `/plx:build` | `$plx:build` | One GPT-6.1 Sol High worker in Codex or Opus 5.5 Medium worker in Claude Code implements and verifies an accepted spec |
| Review | `/plx:review` | `$plx:review` | Three opposite-engine Medium review lanes by default, synthesis, and one host-applied fix round |
| Simplify | `/plx:simplify` | `$plx:simplify` | Four opposite-engine Medium lanes simplify a plan or code; the host applies safe improvements |
| KISS | `/plx:kiss` | `$plx:kiss` | Load the user-authored KISS principles into the current context |
| Orchestrate | `/plx:orchestrate` | `$plx:orchestrate` | Set a planner and worker-delegation posture without starting work |
| Dev | `/plx:dev` | `$plx:dev` | Plan → build → review/fix → final gate |
| Other host | `/plx:codex` | `$plx:claude` | Opposite-engine passthrough with full host access; default model/effort can be overridden |
| Grok | `/plx:grok` | `$plx:grok` | One isolated Grok passthrough; Grok 4.6 always uses medium effort |
| Gemini | `/plx:gemini` | `$plx:gemini` | One sandboxed Gemini CLI passthrough; `auto` model routing by default; no shell or effort flag |
| Devin | `/plx:devin` | `$plx:devin` | One full-access Devin passthrough; SWE-2 High by default; no generic effort flag |
| Init | `/plx:init` | `$plx:init` | Load the Parallax skill map and research defaults into context |
| Unknowns | `/plx:unknown-unknowns` | `$plx:unknown-unknowns` | Host-only blindspot and comprehension work |
| Fanout | `/plx:fanout-and-synthesize` | `$plx:fanout-and-synthesize` | Host-led independent lanes by lens or shard, then one evidence-weighted synthesis |
| Verify | `/plx:adversarial-verification` | `$plx:adversarial-verification` | Host-led verifier lanes try to refute claims; only survivors are kept |
| Generate | `/plx:generate-and-filter` | `$plx:generate-and-filter` | Host-led idea generation, rubric filter, pairwise finalist judging, one recommendation |

All skills are explicit-only so an expensive pipeline never starts merely because a
prompt resembles its description. Codex uses `allow_implicit_invocation: false`; Claude
uses `disable-model-invocation: true` with `user-invocable: true`.

## Model defaults and overrides

| Skill | Claude Code host | Codex host |
| --- | --- | --- |
| Plan | Fable 5.1 authors; `gpt-6-astra` reviews | `gpt-6-astra` authors; `claude-fable-5-1` reviews |
| Build | `claude-opus-5-5` Medium worker | `gpt-6.1-sol` High worker |
| Review, Simplify | Codex `gpt-6.1-sol` Medium | Claude `claude-opus-5-5` Medium |
| Opposite-host passthrough | `/plx:codex`: `gpt-6.1-sol` Medium | `$plx:claude`: `claude-opus-5-5` Medium |
| Orchestrate workers | Opus 5.5 Medium subagents | GPT-6.1 Sol Medium subagents |

Codex, Claude, and Grok passthroughs accept explicit model and effort requests in natural
language (for example, `$plx:claude ask fable medium for <task>`); omitted settings keep
their defaults. Grok 4.6 is always normalized to medium. Devin takes an exact model ID
instead (`swe-2-medium`, `swe-2-high`, `swe-2-max`) and rejects a separate effort value;
an explicitly retryable Devin protocol failure allows up to two fresh retries after
partial work is reconciled. Review and Simplify accept a current-message instruction
that replaces the engine for the whole round. The selected CLI must have access to the
requested model.

Safety, full-access, and Git rules are in [Architecture](ARCHITECTURE.md#runtime-and-safety).

## Runtime tools (package-local `bin/`)

| Tool | Role |
| --- | --- |
| `plx-engine` | Headless engine wrapper (safety pinned) |
| `plx-skill` | Print a pipeline skill or reference |
