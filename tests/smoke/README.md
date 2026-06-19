# Parallax behavioral smoke suite

This is the **end-to-end audit** the deterministic harness (`tests/run.sh`) deliberately
skips. It runs the real skills and engine tools against throwaway 1-file fixtures with
**real (small) model calls**, then asserts on what actually happened and captures the
full transcript of every lane. Use it to confirm the live system works, not just that
it's wired correctly.

> `tests/run.sh` / `tests/smoke-scripts.sh` are static and free. **This suite spends
> tokens** and edits via real models (inside throwaway repos only).

## Two layers

| Layer | What it exercises | How | Cost |
|---|---|---|---|
| **L1 — engines** | `bin/plx-{codex,grok}-{ro,rw}` actually drive the CLIs; `-ro` stays read-only, `-rw` edits land in-repo and are correct | pure shell drives the tools | tiny (≈1 call/tool) |
| **L2 — skills** | each `/plx:*` skill runs start→finish (plan → build → review → gate → docs → commit, etc.) | headless `claude --plugin-dir <this repo>` per skill | real (a full pipeline per skill) |

L2 loads **this working copy** via `--plugin-dir`, so it tests uncommitted changes — not
the installed `0.1.0` cache.

## Run it

```bash
bash tests/smoke/run-smoke.sh                 # L1 only (cheap default)
bash tests/smoke/run-smoke.sh --skills        # L1 + every skill end to end (full audit)
bash tests/smoke/run-smoke.sh --skill dev     # one skill end to end
bash tests/smoke/run-smoke.sh --with-grok ... # add grok lanes (off by default)
bash tests/smoke/run-smoke.sh --dry-run --skills   # prep fixtures + print commands, run nothing
```

Engines that aren't installed/authed are **skipped** (via `plx-preflight`), never failed.
A bare run is safe and quick; the token-spending audit is one flag (`--skills`) away.

## What each skill must do (pass criteria)

| Skill | Tiny task | Passes when |
|---|---|---|
| `dev` | add `median()` to calc.py + a test | exit 0 · diff has `def median` · functional check green · transcript shows a review round |
| `review` | review the buggy calc.py | exit 0 · **no edits** · a finding names the empty-list / `ZeroDivisionError` bug |
| `codex` | guard `average([])` | exit 0 · calc.py edited · `average([]) == 0.0` |
| `grok` | same (with `--with-grok`) | same |
| `init` | run in a bare repo | exit 0 · `AGENTS.md` created · `CLAUDE.md` symlink |
| `plan-goal` | — | **manual** (see below) |

Scenarios live in `scenarios/<skill>.txt` — edit the `TASK:` / `EXPECT_*:` lines there;
no code change needed to retune a check.

## The audit artifact

Every run writes one timestamped dir under `logs/` (git-ignored):

```text
logs/<timestamp>/
  summary.md                       # the cross-layer PASS/FAIL/SKIP table (printed at the end)
  engines/<tool>.{out,log,rc,diff} # L1: each tool's answer, full log, exit code, diff
  skills/<skill>/
    cmd.txt           # the exact claude invocation (reproducible by hand)
    transcript.jsonl  # stream-json: every tool call + nested subagent + message
    diff.patch        # what the skill changed vs the pristine fixture
    repo-status.txt   # git status --short
    check.txt         # the functional check's output
    stderr.log        # claude stderr
```

`transcript.jsonl` is the point of the whole thing — it records the plan-critic, the
worker, the worker's reviewers, and the docs lane, so you can see what each one did.

## plan-goal is a manual check

`/plx:plan-goal` runs a Socratic interview (`AskUserQuestion`) and a mandatory approval
gate, so it can't run under `claude -p` (no human to answer). It's marked `SKIP` in the
automated run. To smoke it by hand:

1. Copy a fixture: `cp -R tests/fixture /tmp/plx-pg && (cd /tmp/plx-pg && git init -q && git add -A && git commit -qm init)`
2. From that dir, run `/plx:plan-goal add a small stats module to calc.py` in an interactive Claude Code session.
3. Confirm: it interviews you, locks the goal at an approval gate, runs the planner lanes, and writes **one** `/goal`-ready spec under `.project/builds/<thread>/`, then prints a paste-ready `/goal` condition pointing at it.

## Fixtures

- `tests/fixture/` (shared) — `calc.py` with the seeded empty-list bug; used by dev/review/codex/grok.
- `tests/smoke/fixtures/bare/` — a 1-file repo with no `AGENTS.md`; used by init.

Each is copied to a fresh `mktemp` + `git init` per skill run; the templates are never edited.
