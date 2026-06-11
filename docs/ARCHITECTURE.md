# Architecture

Parallax is a delegation-first coding workflow for Claude Code.

The public surface is one router skill:

```text
/plx:auto <task>
```

The router dispatches to one of three pipelines (each is a skill):

```text
dev | plan | review
```

## Core idea

The orchestrator is the main Claude session — Fable, the most capable and most expensive model. Its value is **judgment**, and its context window is the scarcest resource in the system. So the prime directive:

> The orchestrator never holds bulk content it can delegate.

Subagent lanes burn the tokens — reading files, writing code, producing review transcripts — and hand back only the distilled artifact Fable needs for its next decision. Every skill is therefore a **context-routing policy**: what goes out, what comes back, in what compressed shape.

The model split makes this concrete: the orchestrator is Fable; subagent lanes run **Opus** (or drive Codex/Grok through the engine tools). Opus does bulk work cheaply; Fable's context only ever holds compact artifacts.

Fable does exactly two things itself: **judgment** (plan synthesis, review synthesis as the pseudo-fourth reviewer) and the **fix** (applying the repair plan — by then it has already read the relevant code during synthesis, so a handoff would cost more time and more total tokens). Plan, build, and review are always delegated.

**Code with Opus, review with Codex** — the cross-model split is deliberate. A different model family reviewing the build gives genuinely independent scrutiny.

## The three atoms

Every behavior is a composition of three stage atoms, each a delegation pattern with a compact return contract:

| Atom | What it does | Who acts | Returns |
|---|---|---|---|
| `plan` | produce an implementation plan | parallel planner lanes (read-only); Fable synthesizes | Plan artifact |
| `build` | execute a plan against the repo | exactly one writer worker | Buildout report (summaries, never code bodies) |
| `review` | independently review the work | parallel read-only review lanes; Fable synthesizes | Findings → repair plan |

Synthesis (plan merge, finding triage, repair planning) is always Fable and never delegated — that is where Fable-level intelligence is the product.

## The dev pipeline — 10 steps

`dev` is the flagship composition: **plan → build → review → fix → docs**.

1. **Delegate planning.** Two parallel planners — `claude-planner` (Opus, xhigh) and `codex-planner` (Codex, xhigh) — draft from the same neutral brief. The plan rubric lives inside the planner agents.
2. **Parallel plans return.** Both planners hand back their Plan artifacts.
3. **Fable synthesizes the plan.** Reviews both, thinks independently, produces the final plan. A judgment pass, not a merge.
4. **Delegate the build.** Fable hands the final plan to one Opus worker (`claude-worker`). Spec only — neutral context.
5. **Buildout report returns.** Every file touched, per-file summary of what changed and why, coding decisions, verification. Summaries and pointers only, never code bodies or diffs — reviewers read the actual code from disk.
6. **Prepare the review handoff.** Fable does **not** read the built code; from the Buildout report it writes a small review brief (files touched + what was implemented and why). The review rubrics already live in the reviewer agents.
7. **Parallel multi-lane review.** Three Codex-xhigh reviewer lanes fire — debug, correctness, refine — each read-only, each with neutral context.
8. **Fable synthesizes as pseudo-fourth reviewer.** Merges the three reports and uses its own intelligence: verifies claims, surgically reads suspect code, kills false positives, intuits gaps. Output: the repair plan.
9. **Fable fixes inline.** Step 8 already loaded the relevant code into its window, so Fable applies the repair plan itself, then runs the plan's verification commands. (Escape hatch: structural rework → delegate the repair plan as a fresh build.)
10. **Docs + commit.** A docs subagent updates documentation, then a **local commit only** — never a push, PR, or publish.

The pipeline has exactly **seven subagent spawns** (2 planners + 1 builder + 3 reviewers + 1 docs).

## Pipelines

| Pipeline (skill) | Config key | Purpose | Steps |
|---|---|---|---|
| `dev` | `dev` | build a change end to end | 1–10 |
| `plan` | `plan` | think only, no edits | 1–3 |
| `review` | `review` | audit / debug / critique without edits | 6–8 (read-only) |

`/plx:auto` routes among these three; explicit `/plx:*` commands force one (see [`COMMANDS.md`](COMMANDS.md)). The single-engine passthroughs `/plx:codex` and `/plx:grok` run a task through one engine with no review pipeline.

**Disabled / parked:** the `team-*` and `ultra-*` skills have their `SKILL.md` renamed to `DISABLED.md`. When revived they are regenerated from `.project/VISION.md` — the same dev skeleton with more engines in the read stages (e.g. ultra adds Grok lanes and a plan-review stage).

## Rubrics live in the agents

Any prompt text that is the same every run — review dimension rubrics, the plan-quality rubric, the Finding Schema, output templates — is baked into the **agent files**, alongside each engine agent's operator manual for the `plx-*` tools. The orchestrator's spawn message carries only what changes per task: repo path + task-specific brief. Fable hands each subagent **the work, not the command**.

## Safety model

- Plan and review lanes are read-only for every engine. There is exactly **one writer at a time, always**: the build worker, plus Fable applying the repair plan.
- Codex/Grok review and plan calls go through `bin/plx-codex-ro` / `bin/plx-grok-ro` (read-only).
- A non-Claude writer (when `config/parallax.yaml` binds `code: codex`/`grok`) goes through `bin/plx-codex-rw` (scoped `workspace-write`) / `bin/plx-grok-rw` (kernel `workspace` sandbox) — edits confined to the target repo. The default config keeps Claude the sole writer.
- Engine wrappers never use `danger-full-access`, `--dangerously-bypass-approvals-and-sandbox`, or `--yolo`.
- Neutral context: lanes get the spec, never the orchestrator's analysis or another lane's output.
- Fable never reads built code before review synthesis — and at synthesis only surgically, guided by the findings.
- Parallax does not create `.parallax/`, `.parallax/cache`, or `.parallax/runs` in target repos. Runtime prompts, logs, and engine outputs are chat context or temp files cleaned up before commands return.
- Every dev run ends with a docs subagent and a local commit — never a push, PR, or publish step.

## Hooks policy

Parallax v0.1 installs no hooks. Safety comes from: one public `plx` router, a deterministic engine API (`bin/plx-*`) with uniform flags, uniform exit codes (0 ok · 1 engine failure · 2 usage error · 3 auth needed), `--help` manuals, and safety flags pinned in code; read-only review/plan invocations; scoped-write tools for an opt-in non-Claude writer; and no repo-local runtime state.

## References

`base-prompts/` holds the canonical prompt blocks (plan rubric, build discipline, the review dimension rubrics, the Finding Schema, templates) as **storage only** — nothing reads it at runtime. Skills inline the blocks and agents carry the rubrics; editing a base prompt does not change them (propagate by hand).
