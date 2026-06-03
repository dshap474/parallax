# Architecture

Polyphony is a **role-based build pipeline** that runs across multiple models. This doc
explains the moving parts: the pipeline, roles, engines, and combos.

## The core idea

Most "AI writes code" workflows use one model end to end. Polyphony separates **writing**
from **reviewing** and gives them to *different* models:

- **One writer** — Claude. It plans, writes (directly or via a fresh worker), and applies
  all fixes. Having a single writer keeps the code coherent.
- **Independent reviewers** — Codex (and Grok in v0.2), plus a fresh Claude reviewer. They
  are **read-only** and **fresh** (they never saw the code being written), so their
  judgment isn't anchored to the author's.

The orchestrator (the Claude main loop) is the synthesis hub: it merges plans, merges
review findings, and applies edits.

> **Why:** in practice the reviewer engine catches more than the writer engine. A model
> reviewing its *own* output rationalizes its mistakes; a different model, blind to the
> author's reasoning, doesn't. See [`BENCHMARK.md`](BENCHMARK.md).

## The pipeline (shared, engine-agnostic)

```
1 Plan ─▶ 2 Plan-review ─▶ 3 Code ─▶ 4 Refine ─▶ 5 Review ─▶ 6 Fix
```

| # | Stage | Role | Edits repo? |
|---|---|---|---|
| 1 | Plan | orchestrator | no |
| 2 | Plan-review | read-only reviewer | no |
| 3 | Code | writer | **yes** |
| 4 | Refine | writer (direct) | **yes** |
| 5 | Review | read-only reviewers (Debug ∥ Correctness, parallel) | no |
| 6 | Fix | writer (direct) | **yes** |

The full stage spec lives in each skill's `references/pipeline.md`. Two rules matter most:

- **Neutral Context Rule** (Stages 2 & 5): a fresh reviewer gets *only* the artifact, the
  original task/spec, and its lane brief — never the orchestrator's analysis or conclusions.
  It must re-derive judgment.
- **One-turn parallel review** (Stage 5): all reviewers fire in a single orchestrator turn
  (background CLI calls + spawned subagents together), then results are collected. This is
  the pipeline's one true parallel point.

## Roles → engines → combos

- A **role** is a pipeline slot (Plan, Plan-review, Code, Refine, Debug, Correctness, Fix).
- An **engine** is a concrete invocation that can fill a role. Polyphony ships five:

  | Engine | Model / tool | Shape |
  |---|---|---|
  | `claude-orch` | the Claude main loop (you) | write / synthesize |
  | `worker` | bundled `polyphony:worker` subagent | write |
  | `reviewer` | bundled `polyphony:reviewer` subagent | read-only |
  | `codex-ro` | `codex` CLI, `gpt-5.5`/high | read-only |
  | `composer-ro` | `grok` CLI (v0.2, stub) | read-only |

- A **combo** is a roster mapping every role to an engine. The two skills are two combos:

  | Combo (skill) | Code | Review lanes | Writer |
  |---|---|---|---|
  | `team-dev` | fresh `worker` | `codex-ro` (plan + debug + correctness) + `reviewer` (debug) | Claude |
  | `ultra-dev` | fresh `worker` | 9-reviewer panel: `reviewer` + `codex-ro` + `composer-ro` × refine/debug/correctness | Claude |

Engine invocations (and all the headless hardening) live in `references/engines.md`. To
swap a model for a role, point that roster row at a different engine — the pipeline and
briefs don't change.

## Why a single writer, read-only reviewers

- **Coherence:** one author keeps the code's style and structure consistent.
- **Safety:** reviewers run in read-only sandboxes and physically cannot edit, so a
  misbehaving external CLI can't corrupt the repo.
- **No writer-model risk:** because Codex/Grok never write, model-availability quirks (e.g.
  a writer model being unavailable on some auth) can't break a run.

## The briefs

Five engine-agnostic briefs define *what each lane looks for*, independent of which model
runs it: `coding-spec-template.md`, `refine-guide.md`, `debug.md`, `correctness.md`,
`review-briefs.md` (synthesis + finding schema). They're shared across combos.
