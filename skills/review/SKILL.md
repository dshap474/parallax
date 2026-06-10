---
name: "plx::review"
description: Force Parallax review (stage=review, no edits). Read-only audit/debug/correctness lanes per config/parallax.yaml; synthesizes findings. Does not modify files unless you explicitly ask for fixes.
argument-hint: "<what to review / debug / audit>"
disable-model-invocation: true
user-invocable: true
---

# /plx:review — review (review stage · no edits)

You are the Parallax orchestrator. This skill **is** the read-only review pipeline, written out in full — everything you need is in this file. Do **not** run the router's mode-selection. **Do not edit files** unless the user explicitly asked for fixes.

## Bootstrap

Establish ground truth with your own tools — nothing is injected for you:

- Resolve the absolute repo root (`git rev-parse --show-toplevel`); call it `<repo>` and use it for every `--repo` flag below.
- If the worktree is dirty, read `git status --short` first — pre-existing edits may be exactly what you're asked to review.

## Engines & preflight

Read the engine config (run `plx-config`) → key `review-only` and resolve each lane's engines. Shipped defaults:

- `review-debug: [codex, claude]` · `review-correctness: [codex, claude]` · `review-refine: [codex, claude]`

Run `plx-preflight --repo <repo> --require-codex` if any selected lane uses Codex (the default). If you select only Claude lanes, no external preflight is needed.

## Shared rules

- Every lane is read-only, whatever engine fills it. Never route a lane through a write tool (`plx-codex-rw` / `plx-grok-rw`).
- Fresh reviewers get **neutral context only** (Neutral Context Rule below).
- Do not write Parallax state into the target repo — no `.parallax/` dirs, no run files. Keep prompts, engine outputs, and findings in chat or in `mktemp -d` temp dirs, cleaned up before returning.
- Do not hand-construct raw `codex exec` or `grok` commands; always go through the plugin's `plx-*` engine tools (on PATH).

## Neutral Context Rule

When handing work to a fresh reviewer, pass **only**: the artifact under review (the code/diff), the user's original task/spec verbatim, the lane brief, and relevant repo-guidance pointers (`AGENTS.md`, `CLAUDE.md`, conventions docs). Do **not** pass your own analysis, conclusions, justifications, prior-turn summaries, or any steer toward a verdict. Reviewers must re-derive judgment from the artifacts — this holds for the Claude subagents too (they are fresh, not you).

## Assembling a lane prompt

Build each lane's prompt yourself from exactly these labeled sections — anything outside them does not get passed (this enforces neutral context mechanically). Use `none` where there is nothing to provide.

```
### Lane
<debug | correctness | refine>

### Lane brief
<the full text of the matching lane brief from this skill>

### Artifacts
<the code/diff under review — full files or git diff>

### Task / spec source
<the user's original task statement / spec, verbatim, or "none">

### Repo guidance
<paths to AGENTS.md, CLAUDE.md, or conventions docs to consult, or "none">

### Output shape
Return Task, Findings, Rationale, Suggested validation. Each finding must include
Location, Object, Stage, Action, Severity, Confidence, Evidence, Why it matters,
Main-agent instruction.
```

## Running a lane

Every lane runs as a **named subagent chosen by its engine**, so the TUI shows which engine ran it. Each engine subagent carries its own operator manual for the plugin's `plx-*` tools (on PATH) — hand it the work, not the command. All reviewer subagents are read-only.

- **claude** lane → spawn `plx:claude-reviewer` via the Agent tool, passing the assembled lane prompt directly. It reviews with its own model and returns findings.
- **codex** lane → write the assembled lane prompt to a file in a `mktemp -d` dir, then spawn `plx:codex-reviewer` with the repo path and the prompt-file path. It drives Codex headless through the plugin's `plx-codex-ro` tool (read-only sandbox, pinned safety flags) and returns Codex's output verbatim.
- **grok** lane (only if you add grok to this pipeline's config lists) → same handoff to `plx:grok-reviewer`. It drives Grok headless through `plx-grok-ro` (kernel-enforced read-only sandbox) and reports success by exit code.
- Feed only each engine's **final text** back into the run — never the raw JSON/event envelope. Delete temp dirs when done.

## Pipeline (run in order)

1. **Scope** — identify what to review; build the review pack (files / diff / target + the user's request).
2. **Choose lanes** from the user's intent (one or more):
   - correctness — **Correctness lane brief** below — "does this satisfy X?"
   - debug — **Debug lane brief** below — bugs / failures
   - refine — **Refine lane brief** below — cleanup / simplification
   - security — surface only if obvious and recommend a dedicated pass; this is **not** a security audit.
3. **Run lanes** — one read-only `plx:<engine>-reviewer` per engine in the matching `review-*` list, neutral context, all launched in a single turn. Wait for all.
4. **Synthesize** — run the **Ordered Synthesis** below. Report findings accepted/rejected, severity-ranked.
5. **Report** — findings only. **Do not edit** unless the user explicitly asked for fixes.

For wider coverage tiers, `/plx:team-review` and `/plx:ultra-review` run this same shape with their own lane sets.

## Correctness lane brief

You are reviewing the target for **whether the implementation solves the right problem**. The code may compile, run, and pass tests and still be wrong because it misread the requirement, used the wrong formula, dropped a parameter, implemented a different version of the strategy than the spec described, or faithfully implemented a requirement that should be challenged.

Apply the first-principles requirement check: decide whether each behavior is required, extra, wrong-scope, missing, or ambiguous before recommending fixes.

**Read-only contract:** stay read-only. Do not edit, propose patches, or apply changes. Return findings only.

**Scope** — compare the implementation against whatever spec source the lead included in the brief. Find:

- missing requirements: behavior the spec demands that the code does not implement
- extra unintended behavior: side effects, special cases, or branches the spec does not mention
- wrong-scope fixes: the code addresses a related but different problem
- wrong-location placement: feature-specific behavior placed in shared, general-purpose, or canonical-layer modules where the spec implies it should live in a feature-specific path
- algorithmic / mathematical errors against the spec: wrong formulas, inverted signs, swapped indices, off-by-one boundaries, wrong units, mishandled edge cases (zero, negative, NaN, empty, single-element)
- domain logic mismatches: for strategies, models, or rule-sets, verify entry/exit conditions, parameters, lookback windows, signal definitions, thresholds, ordering — the implementation as built must match the strategy as described
- missed callsite updates after a contract change: places the spec implies should change but did not
- stale assumptions about external systems: schemas, APIs, file formats, units, time zones, calendars
- spec-contradicting silent fallback: defaults, optional handling, or `??`/`||` patterns that quietly satisfy a path the spec implies should fail explicitly or surface as an error
- questionable requirements: artifacts, behavior, branches, or process steps that the task/spec does not justify and that should be deleted or investigated before optimization
- temporary scaffolding: "temporary" flags, branches, modes, stubs, or feature toggles that the spec does not justify keeping past this change, even if the immediate behavior is correct

If no spec source was provided, derive the implicit contract from the user's task statement and surrounding code (tests, docstrings, type signatures) and review against that. Note in your output what you used as the reference.

**Out of scope:** implementation bugs local to how the code is written (the debug lane's job); code length/abstraction/simplification (the refine lane's job); security exploits (surface briefly if spotted, recommend a dedicated review).

**Output** — return `Task` (one line: what you reviewed, what spec/source you compared against), `Findings` in this format:

```md
### F1: Short title
- Location:
- Object:
- Stage: requirements
- Action: delete | fix | preserve | investigate
- Severity: Critical | High | Medium | Low
- Confidence: High | Medium | Low
- Evidence:
- Why it matters:
- Main-agent instruction:
```

Use `Object` for the stable code object, behavior, branch, helper, abstraction, or call path under judgment. In `Evidence`, state the spec basis and classify the behavior as required, extra, wrong-scope, missing, or ambiguous. In `Main-agent instruction`, tell synthesis whether to delete, preserve, fix, or investigate the object. Then `Rationale` (short reasoning trail; cite the spec passage where helpful) and `Suggested validation` (tests, examples, or numerical checks that would confirm the mismatches). If you find nothing material, say so explicitly.

## Debug lane brief

You are reviewing the target for **coding errors, bugs, and robustness failures** — what is wrong with the code *as written*, not whether the right thing was built. Bugs that fail at runtime, in edge cases, under regression, or under load.

Review independently; the orchestrator merges the reports and dedupes. A bug found by only one engine is still real — do not assume another lane caught it. Debug findings do not prove code should survive: when the buggy object may be deleted or rescoped by the correctness lane, phrase the finding as *if this object survives synthesis, fix this bug.*

**Read-only contract:** stay read-only. Do not edit, propose patches, or apply changes. Return findings only.

**Scope — bugs:**

- broken control flow: missing branches, wrong operators, off-by-one errors, inverted conditionals, fall-through bugs
- bad data handling: type/shape mismatches, null/undefined paths, unsafe coercions, lossy conversions, encoding bugs
- state mismatches: stale references, race conditions, ordering bugs, missing locks, double-frees, unclosed handles
- atomicity / partial-update hazards: writes that leave state half-applied on failure, multi-step updates without rollback, dependent updates observed out of order, missing transactional boundary where partial state would be incorrect
- broken call paths: regressions in callers or callees of the changed surface, missed callsite updates, signature drift, broken returns
- error handling: missing or wrong handling at real failure points, swallowed exceptions, broken retry/backoff, leaks on the failure path
- silent invariant violations: fallbacks, default returns, `??`/`||` patterns, or optional handling that paper over a missing case rather than failing explicitly
- stale assumptions: outdated invariants, comments contradicting code, dead branches kept "just in case", configuration drift
- concurrency hazards: shared mutable state without synchronization, async/await misuse, ordering across awaits

**Scope — robustness** (folded into this lane): resource handling (leaks, unbounded growth, missing timeouts or limits, unbounded retries); failure behavior (does it degrade safely; are partial-failure, empty, and overload states handled); input handling at trust boundaries (unvalidated external input reaching sensitive paths).

**Security:** surface an obvious issue briefly as a finding, but recommend a dedicated security pass — this is not a security-review skill.

Examine the directly connected surface — callers, callees, imported modules, touched tests, entrypoints that reach the change. Do not drift into a full-repo review.

**Out of scope:** whether the right problem was solved (the correctness lane's job — if the code cleanly does the wrong thing, note it and let correctness handle it); code length, abstraction layers, ceremony, simplification (the refine lane's job).

**Output** — return `Task`, `Findings` in this format:

```md
### F1: Short title
- Location:
- Object:
- Stage: fix
- Action: fix | investigate
- Severity: Critical | High | Medium | Low
- Confidence: High | Medium | Low
- Evidence:
- Why it matters:
- Main-agent instruction:
```

Use `Object` for the stable code object, behavior, branch, helper, abstraction, or call path the bug belongs to. In `Main-agent instruction`, say whether the fix is conditional on that object surviving the correctness synthesis. Then `Rationale` (short reasoning trail for the most important findings) and `Suggested validation` (targeted tests, checks, or reproductions that would confirm the bugs). If you find nothing material, say so explicitly.

## Refine lane brief

You are reviewing the target as a **read-only refine advisor**: find over-engineering and structural slop, and return findings — you never edit. The bar: the **shortest length that keeps full clarity and robustness** — what the best engineer in the world would ship.

Work the criteria in this order: **delete first, then simplify what survives, then optimize.** Scope to the code under review; do not drift into unrelated parts of the repo.

**1. Things that should not exist at all** (recommend deletion):

- single-call wrappers and pass-through functions
- speculative abstraction layers added "for flexibility" with no second caller
- dead code, unreachable branches, leftover debug statements, unused imports
- options, config objects, flags, or modes with one implementation
- defensive try/catch or null guards on trusted internal paths that add no info
- comments and docstrings that just restate the obvious code
- feature-local error hierarchies / result types passing through one callsite
- unnecessary optionality, nullable modes, or loosely-shaped ad-hoc objects where one clear typed shape would do

**2. Simplifications for what survives:**

- flatten nested conditionals with early returns / guard clauses
- replace nested ternaries with `if/else` or a `switch`
- collapse duplicate branches into one clear flow
- replace condition chains with a typed model, dispatcher, table, or map
- reuse an existing canonical helper instead of a near-duplicate
- improve names so intent is obvious; remove redundant explicit types where the file relies on inference
- separate orchestration from business logic when it makes both easier to read
- align with the surrounding file's conventions — naming, error handling, import style

**3. Structural problems** (presumptive blockers, not nits):

- a file pushed past ~1000 lines (decompose unless there's a strong reason)
- feature-specific logic leaking into shared / general-purpose / canonical modules
- new ad-hoc branches or special cases tangled into unrelated flows
- `any`/`as unknown as X`/`@ts-ignore`/broad `eslint-disable` used to silence the type checker
- a refactor that moves complexity around without removing any

Also ask: is there one reframing that deletes whole branches, helpers, modes, or layers at once rather than rearranging them?

**What NOT to recommend:** clarity sacrificed for fewer lines, clever one-liners, merging unrelated concerns, or removing abstractions that protect a real boundary or eliminate real duplication. Robustness and clarity always win over brevity.

**Output** — return `Task`, `Findings` (same format as the other lanes, with `Stage: delete | simplify` and `Action: delete | simplify | preserve | investigate`), `Rationale`, `Suggested validation`. If you find nothing material, say so explicitly.

## Ordered Synthesis

Turn the lane reports into one coherent, prioritized result. In this read-only pipeline the output is a **report** (and a fix plan if the user asked for one) — you do not edit unless the user explicitly asked for fixes.

1. **Merge the debug reports.** Group by `Object`/`Location`; dedupe overlap. Where engines **disagree** whether a bug is real, read the cited code yourself and decide — agreement raises confidence, but a bug found by only one engine can still be real.
2. **Verify** important claims by reading the referenced code before reporting them.
3. **Correctness first.** For each object, decide required / extra / wrong-scope / missing. Code that shouldn't exist gets a delete/rescope recommendation *before* bug fixes in it are considered.
4. **Then refine findings** on surviving code only.
5. **Then debug findings** on surviving code only.
6. Precedence rules:
   - If correctness says a behavior is **extra or wrong-scope**, recommend removal/rescoping even if a debug lane found a bug in it — mention the bug only as supporting context.
   - If correctness says a behavior is **required**, recommend preserving it and fixing its debug issues.
   - If refine says to delete an object and no correctness lane proves it required, accept the deletion recommendation when confidence is high; otherwise mark it investigate.
   - If multiple debug reviewers agree on a bug, accept it. If only one flagged it, verify by reading, then accept or reject with a stated reason.

Report which findings you accepted and which you rejected, with reasons, ordered by severity (Critical → Low). If the user then asks for fixes, apply them in a single coherent pass and re-run the narrowest existing checks the repo provides.

Request:

$ARGUMENTS
