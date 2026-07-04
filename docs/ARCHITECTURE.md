# Architecture

Parallax is a delegation-first coding workflow for Claude Code, packaged as a toolbox.

The public surface is three pipelines (each is a skill):

```text
dev | goal-spec | review
```

## Core idea

The orchestrator is the main Claude session — Fable, the most capable and most expensive model. Its value is **judgment**, and its context window is the scarcest resource in the system. So the prime directive:

> The orchestrator never holds bulk content it can delegate.

Headless engine lanes burn the tokens — reading files, writing code, producing review transcripts — in their own contexts, and land results in out-files the orchestrator reads selectively. Every skill is therefore a **context-routing policy**: what goes out, what comes back, in what compressed shape.

**There are no subagents.** Evals showed that operator subagents — a Claude agent whose only job is to assemble a prompt and shell out to an engine wrapper — add wall-clock time without adding quality. The orchestrator calls the engines headless itself, through one wrapper:

```text
plx-engine --engine codex|grok|claude --mode ro|rw --repo <abs> \
  --prompt-file <brief> [--rubric <name>] [--effort <e>] [--model <m>] \
  (--stdout | --out <f> --log <f>)
```

What the subagents used to carry — the lane rubrics — now ships in `prompts/` (one deduped, engine-agnostic file per lane) and is injected at runtime by `--rubric` name: prepended to the prompt for Codex/Grok, appended to the system prompt (`--append-system-prompt-file`) for Claude. The caller's brief file opens with the section header the rubric expects (`## Review brief`, `## Task brief`, `## Draft plan`, `## Spec`).

`prompts/engines.md` is the judgment doc: engine characteristics, how to choose, when to escalate. Config values are **defaults, not limits** — the orchestrator has standing permission to swap engines or raise effort when output is weak.

Fable spends its own intelligence at exactly three points: **plan authoring**, **review synthesis**, and the **final gate**. Everything bulk — the plan critique, the build, the review reads — runs in external engine lanes. The writer stays external even when it is Claude (`--engine claude --mode rw`): it preserves the orchestrator's context hygiene and keeps the review independent of the code's author.

**Cross-engine review is the default posture** — review with a different engine than the one that wrote. A different model family gives genuinely independent scrutiny.

## The three atoms

Every behavior is a composition of three stage atoms, each a lane pattern with a compact return contract:

| Atom | What it does | Who acts | Returns |
|---|---|---|---|
| `plan` | produce an implementation plan | Fable authors it; read-only lanes advise — a red-team critic in `dev`, parallel consultants in `goal-spec` | draft + critique (dev) / Planning Briefs (goal-spec) → final plan doc |
| `build` | execute a plan against the repo | exactly one rw writer lane | Buildout report (summaries + verification, never code bodies) |
| `review` | independently review the work | parallel read-only lanes; Fable synthesizes and triages | Findings → fixes (in `dev`) or a repair plan (standalone) |

## The dev pipeline — 7 steps

`dev` is the flagship composition: **plan → build → review + fix → final gate → docs**.

1. **Fable authors the plan.** Reads the repo (scoped to what the design needs), settles the approach, writes the plan doc itself to the shared spec template — outcome-first: intent, success criteria, invariants, suggested path, validation.
2. **One cross-engine red-team critic.** A read-only lane (`--rubric plan-critic`, Codex by default) stress-tests the draft against the repo — wrong facts, spec drift, missed work, a materially simpler design, unhandled edges, risk — and returns findings, never a rewrite.
3. **Fable folds the critique.** Adopts or rebuts every finding with a reason, verifying load-bearing claims itself, then finalizes. Escape hatch: a fundamental objection → re-draft.
4. **One writer lane.** Fable writes the final plan to a `## Spec` brief and launches one rw lane (`--rubric worker`, Claude by default). The worker implements, self-verifies with the repo's own checks, and returns a Buildout report — files touched, per-file summaries, decisions, verification. Summaries only, never code bodies.
5. **Fable runs the review round.** It writes one neutral review brief from the Buildout report, launches three read-only lanes in parallel (`reviewer-correctness`, `reviewer-cleanup`, `reviewer-structural`) on engines that didn't write the code, then synthesizes as the integrating reviewer: dedup across lanes, correctness governs, verify each material finding against the cited code, kill false positives. Small fixes it applies itself; a large or risky fix set goes back through the writer engine as **one** rw fix turn. One round, hard cap.
6. **Fable gates the work.** Reads the diff once, with fresh eyes — do the fixes hold, do the residuals matter, was anything missed? Fixes nits inline, re-runs verification. Escape hatch: structural rework → a fresh spec back through step 4.
7. **Docs + commit.** Fable updates `.project/` documentation itself, then a **local commit only** — never a push, PR, or publish.

## Pipelines

| Pipeline (skill) | Config key | Purpose |
|---|---|---|
| `dev` | `dev` | build a change end to end |
| `goal-spec` | `goal-spec` | interview-locked goal planning, no edits |
| `review` | `review` | audit / debug / critique without edits |

Explicit `/plx:*` commands run one of these three (see [`COMMANDS.md`](COMMANDS.md)). The single-engine passthroughs `/plx:codex` and `/plx:grok` run a task through one rw lane with no pipeline.

## Running lanes

- **Always background Bash.** Engine turns can run 10–40+ minutes; foreground Bash caps at 10. Lanes launch with `run_in_background` and `--out`/`--log` files; independent lanes fire in one message so they run concurrently; the harness notifies on completion.
- Grok calls need the Claude Bash sandbox disabled for that call (grok needs network/keychain access); grok's own kernel sandbox still confines it.
- Exit codes are uniform across engines: 0 ok · 1 engine failure · 2 usage error · 3 not signed in.

## Rubrics live in `prompts/`

Any prompt text that is the same every run — the review dimension rubrics, the planner and plan-critic rubrics, the worker contract, the Finding Schema and output templates inside them — lives in `prompts/`, one engine-agnostic file per lane. Skills reference rubrics by bare `--rubric` name only; `plx-engine` resolves the files relative to itself, so skills stay self-contained with no path pointers. The orchestrator's brief carries only what changes per task.

## Safety model

- Critic, planner, and review lanes are `--mode ro`, always. There is exactly **one writer at a time**: the rw writer lane (or its single fix turn), plus Fable fixing nits at synthesis and the gate — never both simultaneously on the same files.
- Safety is pinned inside `plx-engine` per engine, in code:
  - **codex** — `--ignore-user-config --ephemeral`, sandbox `read-only` (ro) / `workspace-write` (rw).
  - **grok** — kernel-enforced sandbox (Seatbelt on macOS, Landlock on Linux): `read-only` (ro) / `workspace` (rw, edits confined to the repo).
  - **claude** — non-bare `claude -p` with `--setting-sources project`; ro = `--permission-mode dontAsk` + `Read,Grep,Glob` allowlist; rw = `--permission-mode acceptEdits` + scoped tool allowlist. Blocked tool calls abort the run rather than hang.
- Wrappers never use `danger-full-access`, `--dangerously-bypass-approvals-and-sandbox`, or `--yolo`. Skills never hand-construct raw `codex` / `grok` / `claude -p` commands — `plx-engine` is the only sanctioned path.
- Neutral context: every review lane gets the same brief, never the caller's analysis or another lane's output.
- Parallax does not create `.parallax/` or any repo-local runtime state. Prompts, logs, and engine outputs live in shell temp directories, cleaned up after the run.
- Every dev run ends with a local commit — never a push, PR, or publish step.

## Hooks policy

Parallax installs no hooks. Safety comes from: one deterministic wrapper (`plx-engine`) with uniform flags, uniform exit codes, `--help` manuals, and safety pinned in code; read-only modes for every advisory lane; a scoped-write mode for the single writer; and no repo-local runtime state.
