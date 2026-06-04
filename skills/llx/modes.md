# Parallax modes

This file is the canonical executable workflow authority. `router.md` chooses the mode and preflight policy; this file defines what to do after selection.

## Shared rules

- Claude is the only writer.
- External engines are reviewers/advisors only.
- Fresh reviewers receive neutral context only.
- Use `${CLAUDE_SKILL_DIR}/references/review-briefs.md` for review prompt shape.
- Use `${CLAUDE_SKILL_DIR}/scripts/make-review-prompt.sh` to build external model prompts.
- Use `${CLAUDE_SKILL_DIR}/scripts/codex-ro.sh` for Codex.
- Use `${CLAUDE_SKILL_DIR}/scripts/grok-ro.sh` for Grok.
- When invoking `grok-ro.sh` through Bash inside Claude Code, disable the Claude Bash sandbox for that wrapper call only.
- Store prompts, logs, outputs, findings, specs, diffs, and final results in the absolute run directory printed by intake.
- Every mode writes `<run-dir>/results.md` with selected mode, artifacts, reviews run, fixes or findings, verification, and residual risk.
- Modes that run external reviewers should run `${CLAUDE_SKILL_DIR}/scripts/collect-outputs.sh --run-dir <run-dir>` before writing `results.md`.

## Mode: quick

Steps:

1. Read request.
2. Inspect target files.
3. Write a minimal plan.
4. Edit directly with Claude.
5. Run narrowest relevant checks.
6. Write `results.md`.
7. Return final summary.

No Codex.
No Grok.
No worker unless the edit grows beyond quick scope.

## Mode: team

This is the default `llx` team behavior.

Steps:

1. Plan.
2. Write per-task specs using `references/coding-spec-template.md`.
3. Build plan-review prompt:
   - lane: `plan-review`
   - artifact: plan/spec
   - brief: `references/correctness.md`
4. Run Codex read-only plan review.
5. Reconcile only Critical/High or materially valid findings.
6. Delegate code to fresh `worker` with the final per-task spec only.
7. Claude directly refines using `references/refine-guide.md`.
8. Build review pack from:
   - original request
   - final spec
   - edited file list
   - git diff
9. Run review lanes in parallel:
   - Codex debug
   - Claude reviewer debug
   - Codex correctness
10. Synthesize findings using `references/review-briefs.md`.
11. Claude applies fixes directly.
12. Run narrowest relevant checks.
13. Run `${CLAUDE_SKILL_DIR}/scripts/collect-outputs.sh --run-dir <run-dir>`.
14. Write `results.md`.

## Mode: panel

This is `team` plus optional Grok review lanes.

Steps:

1. Run `team` through Claude refine.
2. Review lanes:
   - Codex debug
   - Claude reviewer debug
   - Grok debug if available
   - Codex correctness
   - Grok correctness if available
   - optional refine advisory from Codex/Grok only if diff is large or structural
3. Synthesize correctness first, then refine, then debug.
4. Claude fixes.
5. Verify.
6. Run `${CLAUDE_SKILL_DIR}/scripts/collect-outputs.sh --run-dir <run-dir>`.
7. Write `results.md`.

If Grok is missing, continue as `team`.

## Mode: ultra

This is `llx` ultra behavior.

Steps:

1. Receive and frame request.
2. Run plan panel in parallel:
   - Claude reviewer plan
   - Codex plan using `${CLAUDE_SKILL_DIR}/scripts/make-review-prompt.sh --lane plan`
   - Grok plan x1 using `${CLAUDE_SKILL_DIR}/scripts/make-review-prompt.sh --lane plan`
   - Optional additional Grok plan variants only if cost justified
3. Claude synthesizes one final spec.
4. Fresh `worker` implements final spec.
5. Claude assembles review pack.
6. Run review panel:
   - refine: Claude reviewer + Codex + Grok
   - debug: Claude reviewer + Codex + Grok
   - correctness: Claude reviewer + Codex + Grok
7. Claude performs ordered synthesis:
   - correctness first
   - delete/wrong-scope before fixing bugs
   - refine surviving code
   - debug surviving code
8. Claude applies one coherent refactor/fix pass.
9. Verify.
10. Run `${CLAUDE_SKILL_DIR}/scripts/collect-outputs.sh --run-dir <run-dir>`.
11. Write `results.md`.

## Mode: review-only

Steps:

1. Identify review scope.
2. Build review pack.
3. Choose lanes:
   - correctness if user asks "does this satisfy X?"
   - debug if user asks for bugs/failures
   - refine if user asks for cleanup/simplification
   - security note only if obvious; this is not a full security audit
4. Run selected reviewers read-only.
5. Synthesize findings.
6. Run `${CLAUDE_SKILL_DIR}/scripts/collect-outputs.sh --run-dir <run-dir>` if any external reviewer ran.
7. Write `results.md`.
8. Do not edit unless the user explicitly asked for fixes.
