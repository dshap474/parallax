---
name: generate-and-filter
description: Generate ideas from independent angles, dedupe and filter them against a task rubric, compare distinct finalists pairwise, and recommend one. Use only when the user invokes Generate-and-Filter.
argument-hint: "<what to generate ideas for, and how many options you want>"
disable-model-invocation: true
user-invocable: true
---

# Generate-and-Filter

Generate many ideas, filter them to a few distinct finalists, and judge those finalists
head to head. You lead: you choose the angles, write the rubric, and make the
recommendation. Works for any choice among ideas: designs, names, approaches,
architectures, strategies. This judges ideas; it does not build them.

## Goal
The requested number of genuinely different options (default three), each with its
case and risks, plus one recommendation and why it beat the others.

## Workers
Launch every generator and judge as `claude-sonnet-5-5` subagents at high effort. An explicit user model or effort
replaces this default. If that worker is unavailable, say so instead of silently
substituting.

## Rubric
Before generating, write a short rubric from the user's goal and constraints: what a
strong option must do, what disqualifies one. If the goal is too vague to judge
against, ask the user before spending lanes.

## Flow
1. Generate: at least two generator lanes, each with a distinct angle (for example
   conventional, contrarian, user-first, constraint-first, borrowed from another
   domain); you decide how many. Each returns several concise idea briefs.
2. Filter: merge duplicates and near-duplicates, cut ideas that fail the rubric, and
   pick finalists that differ meaningfully from each other, not just the top scorers.
3. Judge: compare every pair of finalists with independent judge lanes. Each judge
   sees two briefs and the rubric and returns which is stronger and why.
4. Recommend: rank by pairwise wins and the strength of the reasons; break ties
   yourself.

## Invariants
- Generators and judges are independent; never reveal your favourite or another
  lane's output.
- Present finalists in neutral order and alternate A/B position across judges.
- Judge with the rubric and reasons, not vote count alone.
- Read-only. Do not build, prototype, or edit files.

## Stop rules
If a lane fails or returns nothing useful, respawn it once or proceed without it and
say so. Report how many ideas were generated, merged, and cut. Stop any remaining
lanes before finishing.

## Per-generator brief
Goal and constraints: <same for every generator>
Rubric: <the rubric>
Your angle: <one distinct angle>
Work independently. Return several distinct idea briefs: the idea, why it fits, key
references or evidence, and risks.

## Per-judge brief
Goal and rubric: <same for every judge>
Option A: <brief>
Option B: <brief>
Compare these two against the rubric. Return the stronger option, the decisive
reasons, and the main weakness of each.
