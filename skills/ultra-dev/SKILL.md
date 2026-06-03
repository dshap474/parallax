---
name: ultra-dev
description: >-
  Heavyweight multi-model panel. A 5-model plan panel (Claude + Codex + 3 Grok) drafts
  plans, the orchestrator synthesizes one spec, a fresh worker builds it, then a
  9-reviewer panel (Claude + Codex + Grok across refine/debug/correctness) audits the
  result and the orchestrator applies one synthesized refactor. Claude owns every edit;
  Codex and Grok are read-only. Most coverage, highest cost. Requires the `codex` AND
  `grok` CLIs (Grok tier). For everyday work prefer team-dev.
argument-hint: "<feature, refactor, or task to build>"
disable-model-invocation: true
user-invocable: true
---

# ultra-dev — max-effort model panel

> **Grok tier (v0.2).** ultra-dev fans out to a panel of three models and **requires the
> `grok` CLI plus a verified `composer-ro` engine** (`references/engines.md` marks it a
> stub — smoke-test grok read-only first). Until grok is configured, use **`team-dev`**
> (Claude + Codex only). See `docs/REQUIREMENTS.md`.

**Max-effort model panel.** Where a single-reviewer pipeline uses one reviewer per lane,
ultra-dev fans out to a **panel of three models** at both plan and review time. Claude is
the sole writer; Codex and Grok Composer are **read-only** at every stage (plan panel +
review panel). The orchestrator (`claude-orch`) is the synthesis hub — it merges five
plans into one spec and nine reviews into one refactor.

This skill **restructures** the shared 6-stage flow into a panel topology — follow the
flow below. Lane *content* still comes from the shared briefs (`refine-guide.md`,
`debug.md`, `correctness.md`); invocations from `engines.md`. Note: here **refine is a
review-panel lane** (advisory), not a separate pre-review edit stage — the orchestrator
applies refine + debug + correctness together in the refactor.

## Flow

1. **Receive + synthesize** — `claude-orch` reads the user request and frames the problem.
2. **Plan panel (×5, read-only, parallel):** spawn `reviewer` ×1 + `codex-ro` ×1 +
   `composer-ro` ×3, each drafting a plan from the request (brief: `coding-spec-template.md`).
   Neutral Context Rule.
3. **Spec synthesis** — `claude-orch` merges the five plans into one final per-task spec
   (the linchpin; reconcile disagreements, keep the strongest approach).
4. **Code** — a fresh **`worker`** builds the spec *(default — keeps the orchestrator's
   context lean across the heavy synthesis loads; toggle: `claude-orch` codes directly for
   a small task).*
5. **Review-spec** — `claude-orch` assembles the review pack: a short overview + the
   original spec + the list of edited files (+ the diff).
6. **Review panel (×9, read-only, parallel, one turn):** for **each** of the three lanes —
   **refine** (`refine-guide.md`), **debug** (`debug.md`), **correctness** (`correctness.md`)
   — spawn one `reviewer` + one `codex-ro` + one `composer-ro` (3 lanes × 3 models = 9).
   Each reviewer is fresh, neutral-context, and de-spawns after returning findings only.
7. **Refactor synthesis** — `claude-orch` runs the Ordered Synthesis (`review-briefs.md`)
   across all nine reports (merge + dedupe; correctness-first, then refine, then debug on
   surviving code) into one refactor plan.
8. **Refactor** — `claude-orch` applies the refactor directly *(default — it just
   synthesized the plan and holds the full picture; toggle: hand the refactor plan to a
   fresh `worker` if the change set is large).* Then verify (repo's venv/toolchain
   binaries, never `uv run`).

## Engine roster

| Role | Engine(s) | Shape | Invoke | Brief |
|---|---|---|---|---|
| Plan panel (×5) | `reviewer` + `codex-ro` + `composer-ro`×3 | read-only | `engines.md` | `coding-spec-template.md` |
| Spec synthesis | `claude-orch` | — | — | `coding-spec-template.md` |
| Code | `worker` (fresh) *[default]* / `claude-orch` | write | `engines.md` | final spec |
| Review panel (×9) | per lane: `reviewer` + `codex-ro` + `composer-ro` | read-only | `engines.md` | `refine-guide.md` · `debug.md` · `correctness.md` |
| Refactor synthesis | `claude-orch` | — | — | `review-briefs.md` |
| Refactor | `claude-orch` (direct) *[default]* / `worker` | write | `engines.md` | refactor plan |

## Notes

- **Claude is the sole writer.** Code (fresh `worker`) and refactor (orchestrator) are the
  only edits; Codex and Grok never write — they plan and review read-only. The 3 Claude
  review-panel members are fresh `reviewer`s, independent of the `worker` that built the code.
- **Panel synthesis is the orchestrator's job.** Five plans → one spec (step 3); nine
  reviews → one refactor (step 7). Agreement across models raises confidence; a finding
  from one model can still be real — verify by reading before acting.
- **Refine is a review lane here**, not a pre-review edit stage. The panel's refine
  reviewers produce findings (per `refine-guide.md`); the orchestrator folds them into the
  refactor alongside debug + correctness. State a one-line Structural Verdict in the
  refactor synthesis.
- **Fire each panel in one turn** — background the Codex/Grok CLI calls and spawn the
  Claude subagents together; wait for all. The plan panel is 5 concurrent; the review
  panel is 9 concurrent (within the agent concurrency cap — excess queue).
- **Grok is read-only** (`composer-ro`): invoke with no-edit permissions
  (`--permission-mode plan` or `--disallowed-tools`). The orchestrator's Bash sandbox must
  be disabled for grok calls (see the Composer notes in `engines.md`). **`composer-ro` is
  a stub — smoke-test it before the first run.**
- **Cost:** the heaviest pipeline — 5 planners + 9 reviewers + 2 writes per run. Use when
  breadth of review justifies the spend; for normal work prefer `team-dev`.
- **Preflight:** `command -v codex`, the `grok` binary, and a `gpt-5.5` + `composer-ro`
  probe before Stage 1.
