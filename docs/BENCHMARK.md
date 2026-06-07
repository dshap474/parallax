# Benchmark — Why Cross-Model Review?

Parallax's design bet is that the engine that reviews matters more than the one that writes.

## Setup

A deliberately under-specified ticket — "add a `lollipop` chart type to a Python plotting library" — was run through multiple coding workflows. Each workflow had to plan, code, refine, review, and fix. A hidden robustness suite checked empty/None input, single category, all-negative values, NaN/inf, duplicate labels, 100+ categories, and similar edge cases.

## Results

| Workflow | First-pass robustness | Final robustness | Real bugs caught in review |
|---|---|---|---|
| Codex writes, Claude/Codex review | strong | 19/19 | 1 all-negative baseline crop |
| Grok writes, dual review | weak: 16/19, 3 crashes | 19/19 | 3 Highs around NaN/inf and labels |
| Claude writes, Codex reviews (`plx` team mode) | strongest: 19/19 | 19/19 | 1 real logic bug |

All workflows reached the same final quality: 19/19, lint-clean, tests green. The useful signal was upstream of the final artifact.

## Findings

1. Claude's first pass was strongest on this task.
2. Cross-model review caught real defects the author missed.
3. The pipeline helped the weakest writer most, but still found real issues for strong writers.

The headline case: Codex reviewing Claude-authored code found a truthiness bug in a numeric-column check that made a valid `DataFrame([1, 2, 3])` render an empty figure. Claude's own review lanes missed it; the cross-model lane caught it.

## Takeaway

With a strong writer, the default `team-dev` pipeline is enough for ordinary work. The heavier `ultra-dev` pipeline (3-engine plan panel + full review) is for broader risk, ambiguity, or high-stakes changes.

## Caveats

This was one fixed task and one run per workflow. Treat it as directional evidence, not a statistically robust ranking.
