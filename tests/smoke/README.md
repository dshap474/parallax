# Parallax Claude-package behavioral smoke suite

This is the **end-to-end audit** the deterministic harness (`tests/run.sh`) deliberately
skips. It runs the real Claude skills and the real engine wrapper against throwaway 1-file
fixtures with **real (small) model calls**, then asserts on what actually happened and
captures the full transcript of every lane. Use it to confirm the live system works, not
just that it's wired correctly.

> `tests/run.sh` / `tests/smoke-scripts.sh` are static and free. **This suite spends
> tokens** and edits via real models (inside throwaway repos only).

## Two layers

| Layer | What it exercises | How | Cost |
|---|---|---|---|
| **L1 — engines** | `bin/plx-engine` actually drives each CLI (codex, claude; grok opt-in); `--mode ro` stays read-only and `--rubric` injection lands (the reviewer finds the seeded bug); `--mode rw` edits land in-repo and are correct | pure shell drives the wrapper | tiny (2 calls/engine) |
| **L2 — skills** | each `/plx:*` skill runs start→finish (plan → red-team → build → review lanes → fixes → gate, etc.) | headless `claude --plugin-dir <this repo>` per skill | real (a full pipeline per skill) |

L2 loads `plugins/claude/plx` via `--plugin-dir`, so it tests uncommitted changes — not
the installed cache. The Codex package is covered by the deterministic dual-package
suite. Claude skills launch their engine lanes as background shell calls inside that
headless session, so the runner sets `CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0` — without
it, headless `claude -p` stops waiting on background work after 10 minutes and long lanes
get orphaned.

## Run it

```bash
bash tests/smoke/run-smoke.sh                 # L1 only (cheap default)
bash tests/smoke/run-smoke.sh --skills        # L1 + every skill end to end (full audit)
bash tests/smoke/run-smoke.sh --skill dev     # one skill end to end
bash tests/smoke/run-smoke.sh --with-grok ... # add grok lanes (off by default)
bash tests/smoke/run-smoke.sh --dry-run --skills   # prep fixtures + print commands, run nothing
```

Engines that aren't installed/authed are **skipped** (via `plx-preflight`), never failed.
A bare run is safe and cheap; the token-spending audit is one flag (`--skills`) away.
A full `--skills` run can take a long wall-clock time (each pipeline runs multiple
engine turns) — run it from a terminal, or via background Bash from an agent session.

## What each skill must do (pass criteria)

| Skill | Tiny task | Passes when |
|---|---|---|
| `plan` | plan a `median()` addition | exit 0 · **no edits** · the delivered plan mentions `median` |
| `build` | guard `average([])` (raw bounded task) | exit 0 · calc.py edited · `average([]) == 0.0` |
| `dev` | add `median()` to calc.py + a test | exit 0 · diff has `def median` · functional check green · transcript shows a review round |
| `review` | review the buggy calc.py | exit 0 · a finding names the empty-list / `ZeroDivisionError` bug · **the fix is applied** (`average([]) == 0.0`) |
| `codex` | guard `average([])` | exit 0 · calc.py edited · `average([]) == 0.0` |
| `grok` | same (with `--with-grok`) | same |
| `agents-memory` | run in a bare repo | exit 0 · `AGENTS.md` created · `CLAUDE.md` symlink |
| `goal-spec` | — | **manual** (see below) |

Scenarios live in `scenarios/<skill>.txt` — edit the `TASK:` / `EXPECT_*:` lines there;
no code change needed to retune a check.

## The audit artifact

Every run writes one timestamped dir under `logs/` (git-ignored):

```text
logs/<timestamp>/
  summary.md                             # the cross-layer PASS/FAIL/SKIP table (printed at the end)
  engines/<engine>-{ro,rw}.{out,log,rc,diff}  # L1: each lane's answer, full log, exit code, diff
  skills/<skill>/
    cmd.txt           # the exact claude invocation (reproducible by hand)
    transcript.jsonl  # stream-json: every tool call, background lane launch, message
    diff.patch        # what the skill changed vs the pristine fixture
    repo-status.txt   # git status --short
    check.txt         # the functional check's output
    stderr.log        # claude stderr
```

`transcript.jsonl` is the point of the whole thing — it records the plx-engine lane
launches (critic, writer, reviewers) and the orchestrator's synthesis, so you can see
what each lane did. The lanes' own outputs land in the run's temp dir, which the skill
cleans up — the transcript is the durable record.

## goal-spec is a manual check

`/plx:goal-spec` runs a Socratic interview (`AskUserQuestion`) and a mandatory approval
gate, so it can't run under `claude -p` (no human to answer). It's marked `SKIP` in the
automated run. To smoke it by hand:

1. Copy a fixture: `cp -R tests/fixture /tmp/plx-pg && (cd /tmp/plx-pg && git init -q && git add -A && git commit -qm init)`
2. From that dir, run `/plx:goal-spec add a small stats module to calc.py` in an interactive Claude Code session.
3. Confirm: it interviews you, locks the goal at an approval gate, runs the planner and critic lanes, and writes **one** `/goal`-ready spec under `.project/builds/<thread>/`, then prints a paste-ready `/goal` condition pointing at it.

## Fixtures

- `tests/fixture/` (shared) — `calc.py` with the seeded empty-list bug; used by plan/build/dev/review/codex/grok and the L1 engine lanes.
- `tests/smoke/fixtures/bare/` — a 1-file repo with no `AGENTS.md`; used by agents-memory.

Each is copied to a fresh `mktemp` + `git init` per run; the templates are never edited.
