# Parallax behavioral smoke suite

This is the **end-to-end audit** the deterministic harness (`tests/run.sh`) deliberately
skips. It runs the selected host skills and the real engine wrapper against throwaway 1-file
fixtures with **real (small) model calls**, then asserts on what actually happened and
captures the host log and final answer. Use it to confirm the live system works, not
just that it's wired correctly.

> `tests/run.sh` / `tests/smoke-scripts.sh` are static and free. **This suite spends
> tokens** and edits via real models (inside throwaway repos only).

## Two layers

| Layer | What it exercises | How | Cost |
|---|---|---|---|
| **L1 — engines** | `bin/plx-engine` actually drives each CLI (codex, claude; grok opt-in); `--mode ro` stays read-only and `--rubric` injection lands (the reviewer finds the seeded bug); `--mode rw` edits land in-repo and are correct | pure shell drives the wrapper | tiny (2 calls/engine) |
| **L2 — skills** | each `/plx:*` skill runs start→finish (plan → red-team → build → review lanes → fixes → gate, etc.) | selected headless host per skill | real (a full pipeline per skill) |

L2 defaults to `plugins/claude/plx` via `--plugin-dir`. Set `PLX_PACKAGE=codex` to
run the Codex host through packaged `plx-engine`, with an explicit instruction to read
this checkout's exact `SKILL.md`. This exercises workflow behavior from source; it does
not verify installed Codex plugin discovery or desktop approval UI. Both hosts test
uncommitted changes. Claude skills launch their engine lanes as background shell calls inside that
headless session, so the runner sets `CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0` — without
it, headless `claude -p` stops waiting on background work after 10 minutes and long lanes
get orphaned.

## Run it

For a focused check of prompt routing, report-only decisions, and Devin retry decisions:

```bash
python3 tests/smoke/decisions.py --host codex
python3 tests/smoke/decisions.py --host claude
```

These four cases use real host model calls with the current skill text and simulated
downstream results. They check the proposed prompt or action, including refusal to
replay an ambiguous remote mutation. They do not execute downstream engines or prove
end-to-end skill behavior. `--dry-run` writes prompts without model calls. Prompts,
answers, and logs are retained in the printed temporary directory. Failures exit nonzero.

```bash
bash tests/smoke/run-smoke.sh                 # L1 only (cheap default)
bash tests/smoke/run-smoke.sh --skills        # L1 + every skill end to end (full audit)
bash tests/smoke/run-smoke.sh --skill dev     # one skill end to end
bash tests/smoke/run-smoke.sh --with-grok ... # add grok lanes (off by default)
bash tests/smoke/run-smoke.sh --dry-run --skills   # prep fixtures + print commands, run nothing
PLX_PACKAGE=codex bash tests/smoke/run-smoke.sh --dry-run --skills
PLX_PACKAGE=codex bash tests/smoke/run-smoke.sh --skill init # real Codex host
```

`--with-grok` adds the L1 Grok probes and the Grok passthrough scenario only. The Build,
Review, Simplify, and Dev scenarios require Grok; they skip when its authentication is
unavailable, regardless of this flag. The Dev scenario covers its preferred writer;
it does not exercise the Codex fallback.

Engines that aren't installed/authed are **skipped** (via `plx-preflight`), never failed.
Even a bare run spends model tokens for L1; use `--dry-run` for a model-free preview.
A full `--skills` run can take a long wall-clock time (each pipeline runs multiple
engine turns) — run it from a terminal, or via background Bash from an agent session.

## What each skill must do (pass criteria)

| Skill | Tiny task | Passes when |
|---|---|---|
| `plan` | plan a `median()` addition | exit 0 · **no edits** · the delivered plan mentions `median` |
| `build` | implement and locally commit an accepted `average([])` spec | exit 0 · calc.py changes · commit contains only calc.py · transcript contains the writer and three Grok review artifact names · final functional check passes |
| `dev` | add `median()` to calc.py + a test | exit 0 · diff has `def median` · functional check green · transcript shows a review round |
| `review` | review the buggy calc.py | exit 0 · a finding names the empty-list / `ZeroDivisionError` bug · **the fix is applied** (`average([]) == 0.0`) |
| `codex` | guard `average([])` | exit 0 · calc.py edited · `average([]) == 0.0` |
| `grok` | same (with `--with-grok`) | same |
| `gemini` | guard `average([])` using file tools | same functional checks; missing Gemini authentication fails the scenario |
| `init` | load routing | exit 0 · no tracked or untracked changes · final answer confirms routing |
| `kiss` | load principles | exit 0 · no tracked or untracked changes |
| `orchestrate` | load planner posture | exit 0 · no tracked or untracked changes |
| `unknown-unknowns` | chat-only calculator blindspot pass | exit 0 · no changes · final answer identifies empty-input failure |
| `simplify` | remove redundant collections | exit 0 · code changes · empty, negative, fractional and generator cases retain results |
| `claude` | guard `average([])` (Codex host only) | same functional checks as `codex` |

Scenarios live in `scenarios/<skill>.txt` — edit the `TASK:` / `EXPECT_*:` lines there;
no code change needed to retune a check.

## The audit artifact

Every run writes a unique directory outside the repository under the system temp directory
(or explicit `PLX_SMOKE_RUNDIR`). DRY and SKIP rows are not behavioral verification:

```text
<run-dir>/
  summary.md                             # the cross-layer PASS/FAIL/SKIP table (printed at the end)
  engines/<engine>-{ro,rw}.{out,log,rc,diff}  # L1: each lane's answer, full log, exit code, diff
  skills/<skill>/
    cmd.txt           # the exact host invocation (reproducible by hand)
    answer.txt        # final host response; output assertions exclude echoed prompts
    host.log          # Claude host JSONL copy or Codex packaged wrapper log
    transcript.jsonl  # Claude only: stream-json host events
    diff.patch        # what the skill changed vs the pristine fixture
    repo-status.txt   # git status --short
    check.txt         # the functional check's output
    stderr.log        # claude stderr
```

The host log records what the host exposes about launches and synthesis. Nested lane
outputs can be cleaned up by skills and are not guaranteed to be captured in full. Artifact-name transcript assertions are structural evidence; they do not independently prove a nested lane completed or that its review was correct.

The lanes' own outputs land in the run's temp dir, which the skill
cleans up — the transcript is the durable record.

## Fixtures

- `tests/fixture/` (shared) — `calc.py` with the seeded empty-list bug; used by plan/build/dev/review/codex/grok and the L1 engine lanes.
- `tests/smoke/fixtures/redundant/` — sums of squares with redundant collections; used by simplify.

Each is copied to a fresh `mktemp` + `git init` per run; the templates are never edited.
