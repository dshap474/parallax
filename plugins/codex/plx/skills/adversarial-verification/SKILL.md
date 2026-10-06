---
name: adversarial-verification
description: Send claims, findings, or outputs to independent verifier lanes prompted to refute them; keep only what survives. Use only when the user invokes Adversarial-Verification.
argument-hint: "<claims, findings, or output to verify>"
---

# Adversarial Verification

Put claims, findings, or outputs in front of independent verifiers whose job is to
refute them. You lead: you pick what to verify, choose the lenses, and decide what
survives. Works for any claim: a plan, a diagnosis, review findings, research
conclusions, a factual draft, or your own earlier answer.

## Goal
A verdict per item: survived, refuted, or uncertain, with the deciding evidence.

## Workers
Launch every verifier as `gpt-6-luna` subagents at max reasoning. An explicit user model or effort replaces this
default. If that worker is unavailable, say so instead of silently substituting.

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

## Trace
Resolve `<plugin-root>` from this loaded `SKILL.md` path (two directories up).
Before every handled return, record the run (failure is non-fatal):

```
<plugin-root>/bin/plx-eval finish --skill adversarial-verification --host codex --repo <repo> \
  --outcome <pass|fail|partial|aborted> --verification <pass|fail|not-run> \
  || echo "plx-eval finish failed (non-fatal)" >&2
```

## Report
Survivors first, then refuted items with the refuting evidence, then uncertain items
and what would settle them.

## Per-verifier brief
Item to refute: <one claim, finding, or output>
Its stated evidence: <what supports it>
Your lens: <one distinct way it could be wrong>
Try to prove this wrong. Return refuted (true/false), the concrete evidence, and your
confidence. If you cannot decide, return refuted.
