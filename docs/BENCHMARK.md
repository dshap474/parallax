# Benchmark — does cross-model review actually pay?

Polyphony's design bet is that **the engine that reviews matters more than the one that
writes**. This is the evidence that motivated it.

## Setup

A deliberately **under-specified** ticket — "add a `lollipop` chart type to a Python
plotting library" — with the repo's hard constraints but *no* pinned code, field list, or
"copy this existing chart" hint. Each combo had to do the real work end to end (plan →
code → refine → review → fix). A hidden robustness suite (empty/None input, single
category, all-negative, NaN/inf, duplicate labels, 100+ categories, etc.) was run against
each combo's final code — the combos never saw it.

Combos compared: Codex-writes / Claude-writes / Grok-writes single-writer variants, plus
the streamlined Claude-writes + Codex-reviews combo that became `team-dev`.

## Results

| Combo | First-pass robustness | Final robustness | Real bugs caught in review |
|---|---|---|---|
| Codex writes, Claude/Codex review | strong | 19/19 | 1 (all-negative baseline crop) |
| Grok writes, dual review | **weak** (16/19, 3 crashes) | 19/19 | 3 Highs (NaN/inf, broken labels) |
| **Claude writes, Codex reviews** (`team-dev`) | **strongest** (19/19) | 19/19 | 1 (a real logic bug — below) |

**All combos reached the same final quality (19/19, lint-clean, tests green).** The
pipeline works regardless of who writes. The interesting differences were *upstream* of
the final artifact.

## Three findings

1. **The first pass ranks Claude ≥ Codex > Grok.** Claude's fresh first pass scored 19/19
   and independently included an edge-case fix the others missed. Grok's first pass crashed
   on three degenerate inputs and shipped broken value labels.

2. **Review is the load-bearing stage, and cross-model review paid off every time.** Every
   combo's reviewers caught real defects the author missed. The headline case: in the
   Claude-writes combo, **Codex reviewing Claude's code found a genuine logic bug** — a
   `if not numeric_cols.any()` check that tested the truthiness of the column *labels*, so
   a plain `DataFrame([1, 2, 3])` (column named `0`) silently rendered an **empty figure**.
   Claude's own review lanes missed it; the cross-model lane caught it. Fixed to
   `numeric_cols.empty`, with a regression test.

3. **The pipeline adds the most value to the weakest writer.** The Grok-writes combo was
   rescued from a chart that crashed on NaN/inf and never showed labels (16/19 → 19/19).
   For strong writers the pipeline mostly confirmed quality and caught one real bug each.

## Takeaway

With a strong writer (Claude or Codex), a lighter **review-focused** pipeline suffices —
which is exactly what `team-dev` is. A heavier delegated pipeline earns its cost when the
writer is weaker. Either way, **the cross-model review lane is where the bugs die.** That's
why every Polyphony combo keeps writing and reviewing on different models.

## Caveats

Single fixed task, one run per combo — directional signal, not a statistically robust
ranking. A few findings were deferred uniformly as inherited from the library's existing
chart types.
