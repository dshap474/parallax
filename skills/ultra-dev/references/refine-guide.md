# Refine criteria (Stage 4)

The Code engine just wrote this. Coding agents over-engineer — they add wrappers, abstractions, configs, ceremony, and dead branches that nothing requires. Refine makes the code what the best engineer in the world would ship: the **shortest length that keeps full clarity and robustness.** This file defines the criteria; the combo's Refine role decides *who applies them*.

**How refine is applied (see the combo's ENGINE ROSTER):**

- **Direct** — an editor engine reads the code and applies these improvements itself.
- **Delegated** — read-only advisor engines produce refine findings using these criteria; the orchestrator synthesizes one refine plan; the writer engine applies it. Advisors never edit.

Either way, work in this order: **delete first, then simplify what survives, then optimize.** Preserve all required behavior — if you are unsure something is needed, leave it and note it rather than guessing it away.

Keep edits scoped to the code just written. Do not drift into unrelated parts of the repo. Narrow exception: if the new code crosses a module boundary (touches a public API, moves logic between layers, modifies a shared utility), fix the immediate cross-boundary damage at that boundary only.

## 1. Delete before simplifying

Look first for things that should not exist at all:

- single-call wrappers and pass-through functions
- speculative abstraction layers added "for flexibility" with no second caller
- dead code, unreachable branches, leftover debug statements, unused imports
- options, config objects, flags, or modes with one implementation
- defensive try/catch or null guards on trusted internal paths that add no info
- comments and docstrings that just restate the obvious code
- feature-local error hierarchies / result types passing through one callsite
- unnecessary optionality, nullable modes, or loosely-shaped ad-hoc objects where one clear typed shape would do

## 2. Simplify what survives

- flatten nested conditionals with early returns / guard clauses
- replace nested ternaries with `if/else` or a `switch`
- collapse duplicate branches into one clear flow
- replace condition chains with a typed model, dispatcher, table, or map
- reuse an existing canonical helper instead of a near-duplicate
- improve names so intent is obvious; remove redundant explicit types where the file relies on inference
- separate orchestration from business logic when it makes both easier to read
- align with the surrounding file's conventions — naming, error handling, import style
- run genuinely independent work in parallel instead of avoidable sequential orchestration, when it makes the flow simpler

## 3. Structural ambition (code-judo)

Don't just tidy locally. Ask: **is there one reframing that deletes whole branches, helpers, modes, or layers at once** rather than rearranging them? Prefer the version that makes the code feel inevitable in hindsight.

Treat these as presumptive problems to fix, not nits:

- a file pushed past ~1000 lines (decompose unless there's a strong reason)
- feature-specific logic leaking into shared / general-purpose / canonical modules
- new ad-hoc branches or special cases tangled into unrelated flows
- `any`/`as unknown as X`/`@ts-ignore`/broad `eslint-disable` used to silence the type checker
- a refactor that moves complexity around without removing any

## What NOT to do

Do not sacrifice clarity for fewer lines. Do not produce clever one-liners, merge unrelated concerns, remove abstractions that protect a real boundary or eliminate real duplication, or make the code harder to debug or extend. Robustness and clarity always win over brevity.

Keep an abstraction when it protects a real boundary, supports multiple concrete paths, removes real duplication, or makes the main behavior easier to understand.

## Structural Verdict (self-check before review)

Before handing off to Stage 5, state a one-line **Structural Verdict** on the change as it now stands. This replaces the refine review lane — structural quality is owned here, not by the reviewers. Flag any presumptive blocker introduced or left behind (these are not nits):

- a file pushed past ~1000 lines (decompose unless there's a strong stated reason)
- feature-specific logic leaking into shared / general-purpose / canonical-layer modules
- new ad-hoc branches or special cases tangled into unrelated flows
- escape-hatch typing (`any`, `as unknown as X`, `@ts-ignore`, broad `eslint-disable`) hiding real shapes
- a refactor that moved complexity around without removing any

Fix any blocker before review — directly if you are the editor, or by folding it into the refine plan if a separate engine applies. Then record the verdict (`none` if clean) for the final summary.

## Before you finish

Re-read the result and ask: **would the best engineer in the world ship this?** If the code has roughly the same number of concepts, branches, and moving pieces it started with, you probably missed a reframing — look again. Then make sure the behavior the spec required is still intact (run the acceptance checks from the task spec).
