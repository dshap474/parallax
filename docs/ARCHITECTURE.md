# Architecture

Parallax is a delegation-first coding workflow for Claude Code, packaged as a toolbox.

The public surface is three stage skills, their composition, and autonomous-goal prep:

```text
plan | build | review   →   dev (the composition)   ·   goal-spec
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

Lane rubrics ship in `prompts/` (one deduped, engine-agnostic file per lane) and are injected at runtime by `--rubric` name: prepended to the prompt for Codex/Grok, appended to the system prompt for Claude. The caller's brief file opens with the section header the rubric expects (`## Review brief`, `## Task brief`, `## Draft plan`, `## Spec`).

## The escalation ladder

`prompts/engines.md` is the judgment doc, and it makes the config's role — **floor shape, not mandate** — concrete. It carries a cost/intelligence/taste ranking over the reachable models (gpt-5.5 via codex, opus-4.8/sonnet-5 via the claude engine, grok-composer-2.5; fable is the orchestrator itself, never delegated), application rules (intelligence > taste > cost for anything that ships; bulk → cheap; user-facing → taste ≥ 7; fixes → fast and cheap; standing permission to escalate), and the sizing ladder:

| scale | plan | build | review |
| --- | --- | --- | --- |
| trivial | none — decide and go | direct edit or one cheap rw lane | read the diff yourself |
| small | in-context, no critic | 1 worker | 1 correctness lane |
| default | in-context + implementation critic | 1 worker | 3 dims × 1 engine |
| large / risky | spec doc + implementation and system critics | parallel file-disjoint workers | 3 dims × 2 engines, xhigh |

Standalone `/plx:plan` is intentionally deeper than the composite default shown above:
for every non-small request, Fable authors the draft and both plan-critic dimensions run in
parallel on GPT-5.6 Sol at `xhigh`. `/plx:dev` retains proportional plan sizing because it
also pays for build, review, fixes, and the final gate.

The orchestrator **declares its chosen sizing in one line before launching** — the user's veto point. Plan artifacts follow the same logic: a plan is a chat message by default; a spec doc in `.project/builds/` only when the effort is multi-session or another agent must consume it.

Fable spends its own intelligence at exactly three points: **plan authoring**, **review synthesis**, and the **final gate**. The writer stays external even when it is Claude (`--engine claude --mode rw`) — it preserves the orchestrator's context hygiene and keeps the review independent of the code's author. **Cross-engine review is the default posture.**

## The three atoms

| Atom | Skill | Who acts | Returns |
|---|---|---|---|
| `plan` | `/plx:plan` | Fable authors; by default parallel GPT-5.6 Sol `xhigh` implementation/system critics red-team | final plan (chat or spec doc) |
| `build` | `/plx:build` | 1–N writer lanes, one per disjoint path set | Buildout report (summaries, never code bodies) |
| `review` | `/plx:review` | 1–6 read-only lanes; Fable synthesizes; cheap fix lanes apply the confirmed findings | findings → fixes applied (+ batched user question for uncertain calls) |

`/plx:dev` strings the three together plus a final gate (Fable reads the diff once, fresh eyes, fixes nits, re-verifies). `goal-spec` is separate: interview → lock → planner lane → parallel implementation/system red-team → one self-contained `/goal`-ready spec.

## The review-fix loop

Review lanes are read-only and report in the Finding Schema. Fable synthesizes — dedup across lanes, correctness governs, verify-before-trusting, false-positive filter — then triages survivors into **auto-fix** (the default bucket: confirmed finding, unambiguous remedy), **ask-first** (behavior/scope changes the user may not want — one batched question), and **won't-fix** (with reasons). Auto-fix items go to targeted fix lanes on a cheap fast engine (codex at medium effort, or grok) with a `## Spec` brief listing the findings verbatim: scoped fixes don't need taste. One fix round, hard cap; then verification with the repo's own toolchain.

## Running lanes

- **Always background Bash.** Engine turns can run 10–40+ minutes; foreground Bash caps at 10. Lanes launch with `run_in_background` and `--out`/`--log` files; independent lanes fire in one message; the harness notifies on completion.
- Grok calls need the Claude Bash sandbox disabled for that call (grok needs network/keychain access); grok's own kernel sandbox still confines it.
- Failure playbook: exit 1 → read the log, retry once or escalate engines; a failed review lane among survivors → proceed and say so; a hung lane → check the log, kill, relaunch. Exit codes uniform: 0 ok · 1 engine failure · 2 usage error · 3 not signed in.

## Rubrics live in `prompts/`

Any prompt text that is the same every run — the review dimensions, planner, system and implementation plan critics, and worker contract (which also serves the fix lanes) — lives in `prompts/`, one engine-agnostic file per lane. Skills reference rubrics by bare `--rubric` name only; `plx-engine` resolves the files relative to itself, so skills stay self-contained. The orchestrator's brief carries only what changes per task.

## Safety model

- Critic, planner, and review lanes are `--mode ro`, always. Writers — build workers and fix lanes — follow **one writer per disjoint path set**: rw lanes may run in parallel only on non-overlapping files, each brief names the paths it owns, and the orchestrator never edits files a lane owns. The sandboxes are repo-wide; disjointness is brief discipline, so work splits only along genuinely independent seams. Verification runs after all writers land.
- Safety is pinned inside `plx-engine` per engine, in code:
  - **codex** — `--ignore-user-config --ephemeral`, sandbox `read-only` (ro) / `workspace-write` (rw).
  - **grok** — kernel-enforced sandbox (Seatbelt on macOS, Landlock on Linux): `read-only` (ro) / `workspace` (rw, edits confined to the repo).
  - **claude** — non-bare `claude -p` with `--setting-sources project`; ro = `--permission-mode dontAsk` + `Read,Grep,Glob` allowlist; rw = `--permission-mode acceptEdits` + scoped tool allowlist. Blocked tool calls abort rather than hang.
- Wrappers never use `danger-full-access`, `--dangerously-bypass-approvals-and-sandbox`, or `--yolo`. Skills never hand-construct raw `codex` / `grok` / `claude -p` commands — `plx-engine` is the only sanctioned path.
- Neutral context: every review lane gets the same brief, never the caller's analysis or another lane's output. Review scope comes from `git status` against the run's starting snapshot — ground truth, not the worker's self-report.
- **Skills never commit or publish.** Version control follows the target repo's own agent instructions.
- Parallax does not create `.parallax/` or any repo-local runtime state. Prompts, logs, and engine outputs live in shell temp directories, cleaned up after the run.

## Hooks policy

Parallax installs no hooks. Safety comes from: one deterministic wrapper (`plx-engine`) with uniform flags, uniform exit codes, `--help` manuals, and safety pinned in code; read-only modes for every advisory lane; scoped-write modes for the writers; and no repo-local runtime state.
