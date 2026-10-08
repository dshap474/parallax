---
name: fanout-and-synthesize
description: Split a task into independent lenses or shards, run parallel worker lanes, then synthesize one evidence-weighted answer. Use only when the user invokes Fanout-and-Synthesize.
argument-hint: "<task to split across independent lanes>"
---

# Fanout-and-Synthesize

Fan the task out to independent worker lanes, then synthesize one answer. You lead:
you choose the split, write the briefs, and own the final answer. Works for research,
investigation, review, or coding work that divides cleanly.

## Goal
One evidence-weighted answer: consensus, meaningful disagreements, primary
recommendation, remaining uncertainty.

## Workers
Mix two models for coverage: split lanes roughly evenly between `gpt-6-luna` subagents
at max reasoning and `claude-haiku-5-5` engine lanes at xhigh effort. When two lanes
cover similar ground, put them on different models. Engine lanes are read-only; keep
work that writes files or needs web research on subagents. An explicit user model or
effort replaces this mix. If one worker is unavailable, say so and use the other for
every lane.

Resolve `<plugin-root>` from this loaded `SKILL.md` path by removing
`/skills/fanout-and-synthesize/SKILL.md`. Launch each engine lane in the background with
its brief in a fresh temp directory `<tmp>`:

```
<plugin-root>/bin/plx-engine --engine claude --mode ro --repo <repo> \
  --prompt-file <tmp>/<lane>-brief.md --model claude-haiku-5-5 --effort xhigh \
  --out <tmp>/<lane>.md --log <tmp>/<lane>.log
```

If the host sandbox blocks the engine's network or keychain access, request narrowly
scoped host approval for the wrapper call; keep its sandbox active. Delete `<tmp>` when
done.

## Sizing
Use at least two lanes, 8 lanes max; you decide how many. Split by lens (independent angles on the
same question) or by shard (non-overlapping pieces of the same work). Merge lanes that
would do substantially the same work on the same model; never add lanes just to collect votes. For
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
