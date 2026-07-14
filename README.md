# Parallax

Multi-model coding-agent orchestration for Claude Code — as a **toolbox, not a script**.

The orchestrator is Claude (Fable). It drives three coding engines — **Codex, Grok, and Claude itself** — headless, directly, through one wrapper (`plx-engine`). There are no subagents: evals showed operator subagents only add wall-clock time. What survives from them is the part that mattered — the lane rubrics, now shipped in [`prompts/`](prompts/) and injected at runtime by name.

The core idea is an **escalation ladder**: the shipped config is the floor shape, and the orchestrator sizes every run from a shipped judgment doc ([`prompts/engines.md`](prompts/engines.md)) — model rankings by cost/intelligence/taste, plus the ladder. A trivial task gets no machinery at all; the full dev pipeline sizes planning proportionally, then scales workers and review lanes with risk. Standalone `/plx:plan` is intentionally deeper: Fable authors, then one implementation critic and one system critic compare the candidate with the task contract. The orchestrator declares its chosen sizing before launching, so you can veto before tokens burn. Cross-engine review — a different engine than the one that wrote — is the default posture, and confirmed review findings are **fixed automatically** by cheap targeted fix lanes.

Explicit `/plx:*` commands run a stage (`plan`, `build`, `review`), the full run (`dev`), autonomous-goal prep (`goal-spec`), a single engine (`codex`, `grok`), or repo bootstrap (`init`) — see [`docs/COMMANDS.md`](docs/COMMANDS.md). Default engine bindings live in [`config/parallax.yaml`](config/parallax.yaml).

## Install

```text
/plugin marketplace add dshap474/parallax
/plugin install plx@parallax-marketplace
/reload-plugins
```

Then, in any repo:

```text
/plx:dev add a lollipop chart type to the plotting library
```

## The command surface

Each skill is fully self-contained — steps, lane briefs, and engine invocations inline in its `SKILL.md`. Every lane is one `plx-engine` call the orchestrator makes itself, launched as **background Bash** with results in temp out-files it reads selectively.

| Command | Use case |
|---|---|
| `plan` | Fable authors; two parallel critics compare the candidate with the task contract; spec doc only for large or multi-session work |
| `build` | writer lane(s) implement a plan — from a spec path, the conversation, or a raw task; parallel file-disjoint workers for large separable work |
| `review` | sized review round (1–6 read-only lanes) → synthesis → **automatic fixes** via cheap fix lanes; asks only about genuinely uncertain calls |
| `dev` | plan → build → review + fix → final gate, strung together with per-stage sizing |
| `goal-spec` | Socratic interview locks a goal, then a planner lane + red-team produce one self-contained `/goal`-ready spec in `.project/builds/` |
| `codex` / `grok` | single-engine passthrough, no pipeline |
| `init` | bootstrap a repo's agent-docs setup (AGENTS.md, CLAUDE.md symlinks, git-ignored `.project/`) |

`plan`/`build`/`review` exist so you can drive an implementation stage-by-stage; `dev` is those stages in one run. `goal-spec` is a different animal — it preps a spec for an autonomous `/goal` run and writes no code.

Critic, planner, and review lanes are always read-only. Writers follow **one writer per disjoint path set** — any number of parallel read lanes; rw lanes in parallel only on non-overlapping files. Skills never commit — version control follows the target repo's own agent instructions. Parallax writes no repo-local runtime state.

## Choosing engines and sizes

`config/parallax.yaml` binds each pipeline role to a default engine. [`prompts/engines.md`](prompts/engines.md) carries the judgment: a cost/intelligence/taste table over the reachable models (gpt-5.5 via codex, opus/sonnet via the claude engine, Grok 4.5), rules for when to escalate (intelligence > taste > cost for anything that ships; bulk work → cheap engines; user-facing → taste; fixes → fast and cheap), and the sizing ladder. Plan authoring, review synthesis, and the final gate are always the orchestrator.

## Requirements

Parallax orchestrates external model CLIs you install and authenticate yourself. It does not bundle, host, or proxy any model.

| Engine | Install | Used by default |
|---|---|---|
| Codex | `codex` CLI + auth | critic and review lanes, review fixes; `/plx:codex` |
| Grok | `grok` CLI + auth | `/plx:grok`; optional cheap fix/second-perspective lanes |
| Claude | `claude` CLI (already present — it runs the session) | the writer lane; any lane you bind it to |

The shipped configs need Codex. See [`docs/REQUIREMENTS.md`](docs/REQUIREMENTS.md).

## Architecture

Three stage atoms — `plan`, `build`, `review` — exposed as skills and composed by `dev`. The safety model: every lane goes through `plx-engine`, which pins safety per engine in code — Codex config-isolated and sandboxed (`read-only` / `workspace-write`), Grok 4.5 kernel-sandboxed (Seatbelt/Landlock) at medium effort by default, Claude headless with scoped permission modes and tool allowlists. Wrappers never use `danger-full-access`, `--dangerously-bypass-approvals-and-sandbox`, or `--yolo`, and skills never hand-construct raw engine commands. See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Repo layout

```text
parallax/
├── .claude-plugin/{plugin.json, marketplace.json}
├── skills/       # one dir per command; each SKILL.md is fully self-contained
├── prompts/      # lane rubrics (injected via plx-engine --rubric) + engines.md judgment doc
├── config/       # parallax.yaml — default engine bindings (floor shape, not a mandate)
├── bin/          # engine API on PATH (plx-engine, plx-preflight, plx-config, plx-skill, plx-link-claude)
└── docs/{ARCHITECTURE, REQUIREMENTS, BENCHMARK, CONTRIBUTING, SPEC}.md
```

Each `skills/<name>/SKILL.md` carries its pipeline inline — no `${CLAUDE_PLUGIN_ROOT}`, no path pointers, no script injection. Skills reference rubrics by bare `--rubric` name and shared templates via `plx-skill --ref`; both resolve inside the `bin/` tools, so the skills stay self-contained.

## Status

v0.4.3

## License

MIT — see [`LICENSE`](LICENSE).
