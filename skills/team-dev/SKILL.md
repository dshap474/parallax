---
name: team-dev
description: >-
  Multi-model build pipeline (everyday default). Claude plans, a fresh worker writes the
  first pass, the orchestrator refines and fixes directly, and Codex (gpt-5.5, read-only)
  reviews at plan-review + one debug lane + correctness with a fresh Claude reviewer as a
  second debug lane. Claude is the sole writer; Codex never edits. Use for substantial
  features, refactors, or rewrites — not one-line fixes. Needs only the `codex` CLI.
argument-hint: "<feature, refactor, or task to build>"
disable-model-invocation: true
user-invocable: true
---

# team-dev — Claude builds, Codex reviews

**Claude writes; Codex reviews — Claude + Codex only.** The everyday default. Claude owns
every edit (a fresh `worker` writes the first pass; the orchestrator refines and fixes
directly); **Codex never edits** — it is the independent cross-model reviewer at
plan-review, one debug lane, and correctness. A fresh Claude `reviewer` is the second
debug lane. Every reviewer is fresh, read-only, neutral, and de-spawns after returning.

This combo drops delegated apply round-trips (Refine and Fix are single orchestrator
turns) and uses no third writer engine. Every Codex call is read-only, so there is no
writer-model availability risk and no headless write-sandbox to misconfigure. **It needs
only the `codex` CLI** — see `docs/REQUIREMENTS.md`.

Run the shared pipeline in `references/pipeline.md` with the roster below. Invocations:
`references/engines.md`. The Neutral Context Rule applies to Stages 2 & 5.

## Engine roster

| Role | Engine(s) | Shape | Invoke | Brief |
|---|---|---|---|---|
| Plan | `claude-orch` | — | — | `coding-spec-template.md` |
| Plan-review | `codex-ro` | read-only | `engines.md` | `correctness.md` |
| Code | `worker` | write (fresh worker) | `engines.md` | per-task spec |
| Refine | `claude-orch` | **direct edit** | — | `refine-guide.md` |
| Debug review | `codex-ro` + `reviewer` | read-only | `engines.md` | `debug.md` |
| Correctness review | `codex-ro` | read-only | `engines.md` | `correctness.md` |
| Fix | `claude-orch` | **direct edit** | — | `review-briefs.md` |

## Combo notes

- **Claude is the sole writer.** A fresh `worker` writes the first pass from the per-task
  spec (neutral — spec only); the orchestrator (`claude-orch`) refines and fixes directly.
  Codex and the Claude `reviewer` stay read-only throughout.
- **Code is delegated to a fresh worker** to keep the orchestrator's context lean and the
  first pass uncontaminated. **Small task?** The orchestrator may write directly and skip
  the worker — one fewer round-trip.
- **Refine = direct, Fix = direct.** Single orchestrator turns; no advise/plan/apply hops.
- **Codex reviews every gate:** plan-review, one of the two debug lanes, and correctness
  all run on `codex-ro`. Debug stays cross-model (Codex + fresh Claude `reviewer`).
- **The second debug lane (`reviewer`) is the dial** — default on (cross-model is the
  point); drop it for small, low-risk diffs.
- **Preflight** before Stage 1: `command -v codex` + a one-shot `gpt-5.5` availability
  probe (see `engines.md`). No grok, no writer-model risk.

## Optional: the Grok review panel (v0.2)

A broader variant fans the review stage out to a Codex + Grok panel (the "TeamDev" combo
in the project history). It needs the `grok` CLI and a verified `composer-ro` engine, and
ships in **v0.2** — see `docs/REQUIREMENTS.md`. The default combo above is the supported
v0.1 path.
