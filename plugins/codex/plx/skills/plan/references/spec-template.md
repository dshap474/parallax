# Coding Plan / Spec Template

Fill the sections needed for this task and remove unused placeholders. Keep ordinary
plans short; expand for risk, ambiguity, public contracts, or multiple sessions.
Pin the outcome, scope, and invariants while leaving local implementation choices open.

## Task

Title: <short title>
Repo: <absolute path>
Status: <Draft | Ready | In Progress | Blocked | Done>

Add an existing branch, issue, or task ID only when useful.

## Worker Instruction

Implement the spec with the simplest general solution that satisfies its success
criteria. Follow repository guidance, reuse existing patterns, validate system boundaries,
and add dependencies only when required. Stay within scope and preserve pre-existing work.

Follow the invoking workflow's engine settings and ownership rules. Work directly within
your assigned scope. The host owns review. Do not launch reviewers, additional writers, or subagents.

## Intent

<Who needs this change, what it enables, and why.>

## Success Criteria

Pair every criterion with a concrete check and its passing signal. Surface the evidence
in the run output so a reviewer can assess completion.

- [ ] <required behavior> — <command or observation; passing signal>
- [ ] <material edge case or preserved contract> — <check and passing signal>

## Context

<Relevant files and systems, current behavior, desired behavior, and existing patterns
to reuse. Include examples where they resolve ambiguity.>

## Invariants

<State hard constraints, scope exclusions, and contracts that must hold. Include applicable
VISION constraints. Keep only material task-specific non-goals.>

Preserve secrets, existing work, and valid tests. Do not change public APIs, schemas,
auth, permissions, or other excluded behavior beyond the accepted scope. Destructive
operations, production changes, and external publication require explicit authority for
the action and target. Local commits follow repository instructions and the accepted spec.

## Suggested Path

<Likely files, implementation approach, and material alternatives. Omit if unnecessary.>

Use another path when it better satisfies the intent, invariants, and validation.

## Validation

<List concrete acceptance and relevant repository checks. Replace every placeholder
before handoff. For manual checks, state the action and expected observation.>

Choose checks that prove behavior, including integration or visual/runtime checks where
needed. Implement the general solution; do not hard-code to fixtures or visible tests.
For bug fixes, capture reproduction or failing-before evidence when practical, followed
by passing-after evidence. Report commands, results, and any unrun check with its blocker
and useful next check. Do not claim completion without supporting evidence.

## Stop Rules

Stop when the success criteria are satisfied and validation has run. Expand investigation
only to resolve uncertainty, failures, or shared behavior relevant to this task.

Proceed with local, reversible decisions. Ask when requirements conflict, a material
choice is missing, or completion would break an invariant or expand scope. If credentials,
environment, or unrelated baseline failures block verification, report what remains
unverified and the concrete blocker. Do not label unfinished work complete.

## Final Report

Lead with the outcome for a reader who has not seen the work. Include changed files,
material decisions or new dependencies, success-criterion evidence, verification results,
and remaining blockers or risks. Include commit and review evidence when the invoking
workflow requires it. Use a compact natural format and omit empty sections.

## Optional Sections

### Open Questions

<Record unresolved decisions and explicit assumptions.>

### Milestones

For long-running work, list intermediate outcomes and the evidence for each.

| Milestone | Outcome | Evidence |
| --- | --- | --- |
| M1 | <outcome> | <check> |

### Progress Log

For multi-session work, read this log when resuming and append after milestones or before
stopping. Record completed work, evidence, open decisions, and the next concrete action.

### Rollback

<When recovery matters, state what can be reverted or restored and how to verify recovery.
Keep destructive recovery steps within explicitly authorized scope.>

### Visual Direction

<For UI work, give concrete palette, typography, density, motion, and useful references.>
