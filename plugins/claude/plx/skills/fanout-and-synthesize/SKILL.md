---
name: fanout-and-synthesize
description: Split a task into independent lenses or shards, run parallel worker lanes, then synthesize one evidence-weighted answer. Use only when the user invokes Fanout-and-Synthesize.
argument-hint: "[model] <task to split across independent lanes>"
disable-model-invocation: true
user-invocable: true
---

# Fanout-and-Synthesize

Fan the task out to independent worker lanes, then synthesize one answer. You lead:
you choose the split, write the briefs, and own the final answer. Works for research,
investigation, review, or coding work that divides cleanly.

## Goal
One evidence-weighted answer: consensus, meaningful disagreements, primary
recommendation, remaining uncertainty.

## Workers
Every lane runs as a native subagent on one model. Do not mix models or launch engine
lanes.

- **Default:** `claude-haiku-5-5` at xhigh effort.
- **First argument:** if the first word names a model, every lane uses it instead and
  the rest is the task (`/plx:fanout-and-synthesize sonnet <task>`). Short names:
  `haiku` → `claude-haiku-5-5`, `sonnet` → `claude-sonnet-5-5`, `opus` →
  `claude-opus-5-5`, `fable` → `claude-fable-5-1`. A full model ID passes through
  unchanged.
- Effort stays xhigh unless the user names one. If the model is unavailable, say so and
  stop; do not substitute.

Lanes that write files need explicitly owned paths (see Invariants).

## Sizing
Use at least two lanes, 8 lanes max; you decide how many. Split by lens (independent angles on the
same question) or by shard (non-overlapping pieces of the same work). Merge lanes that
would do substantially the same work; never add lanes just to collect votes. For
shards, give every lane the same objective, a disjoint shard, and the same output
shape so results merge cleanly.

## Invariants
- Lanes are independent: never reveal an expected conclusion or another lane's answer.
- Read-only by default. If writes are needed, assign disjoint file ownership; you
  integrate all changes.
- Synthesize only after every lane has returned or been dropped.
- Weight conclusions by evidence, not vote count; verify critical claims directly.

## Stop rules
If a lane fails or returns nothing useful, respawn it once with a sharpened brief or
proceed without it and say so. Stop any remaining lanes before finishing.

## Per-lane brief
Core task: <same task for every lane>
Constraints and evidence: <same boundaries>
Your lens or shard: <one distinct lens, or the exact shard>
Work independently. Return findings, supporting evidence, uncertainty, and a
recommendation. Do not modify files unless your lane owns explicitly listed paths.
