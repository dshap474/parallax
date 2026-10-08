---
name: adversarial-verification
description: Send claims, findings, or outputs to independent verifier lanes prompted to refute them; keep only what survives. Use only when the user invokes Adversarial-Verification.
argument-hint: "<claims, findings, or output to verify>"
disable-model-invocation: true
user-invocable: true
---

# Adversarial Verification

Put claims, findings, or outputs in front of independent verifiers whose job is to
refute them. You lead: you pick what to verify, choose the lenses, and decide what
survives. Works for any claim: a plan, a diagnosis, review findings, research
conclusions, a factual draft, or your own earlier answer.

## Goal
A verdict per item: survived, refuted, or uncertain, with the deciding evidence.

## Workers
Mix two models for coverage: split verifiers roughly evenly between `claude-haiku-5-5`
subagents at xhigh effort and `gpt-6-luna` engine lanes at max effort. Put each item's
verifiers on different models. Engine lanes are read-only; keep work that writes files
or needs web research on subagents. An explicit user model or effort replaces this mix.
If one worker is unavailable, say so and use the other for every lane.

Use the packaged helpers on PATH. Launch each engine lane in the background with its
brief in a fresh temp directory `<tmp>`:

```
plx-engine --engine codex --mode ro --repo <repo> \
  --prompt-file <tmp>/<lane>-brief.md --model gpt-6-luna --effort max \
  --out <tmp>/<lane>.md --log <tmp>/<lane>.log
```

If the host sandbox blocks the engine's network or keychain access, request narrowly
scoped host approval for the wrapper call; keep its sandbox active. Delete `<tmp>` when
done.

## Sizing
List the items first; split compound claims into separately checkable ones. Give each
item at least two verifiers, each with a distinct lens that matches how it could fail
(correctness, evidence/sources, reproduction, edge cases, security, feasibility). Scale
verifiers to how costly a wrong item would be; you decide how many.

## Invariants
- Verifiers are independent and see only the item, its stated evidence, and their
  lens; never share your expected verdict or another verifier's answer.
- Verifiers try to refute. When they cannot decide, the default is refuted.
- An item survives only if a majority of its verifiers fail to refute it.
- Weight by evidence, not vote count: one concrete counterexample beats several
  unsupported passes. Verify critical claims yourself before relying on them.
- Read-only. Verifiers do not fix what they find.

## Stop rules
If a verifier fails or returns nothing useful, respawn it once or proceed without it
and say so. Stop any remaining lanes before finishing.

## Report
Survivors first, then refuted items with the refuting evidence, then uncertain items
and what would settle them.

## Per-verifier brief
Item to refute: <one claim, finding, or output>
Its stated evidence: <what supports it>
Your lens: <one distinct way it could be wrong>
Try to prove this wrong. Return refuted (true/false), the concrete evidence, and your
confidence. If you cannot decide, return refuted.
