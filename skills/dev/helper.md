# /plx:dev — how the pipeline works (plain-English walkthrough)

Human-readable companion to SKILL.md. SKILL.md is the source of truth; this just
narrates the flow. Fable (the orchestrator) conducts and delegates all bulk work —
it spends its own intelligence only twice: authoring the plan, and the final gate.
(SKILL.md numbers this as 7 canonical steps; this splits a couple for readability.)

1. User types /plx:dev with a request. The skill triggers; Fable takes over.

2. Clarify if needed. If the request is fuzzy — unclear scope, an unstated choice
   between real options, a missing constraint — Fable asks a few sharp questions
   first. If it's already clear, it skips ahead.

3. Plan. Fable writes one neutral task brief and hands the same brief to two
   planners in parallel — Claude and Codex. Each studies the repo and returns a
   planning brief (its recommendation + the steelman for the other approach), not a
   finished plan. Fable synthesizes the two, settles the design itself, and authors
   the final plan. First place Fable spends its own intelligence.

4. Build. Fable hands the final plan (spec only — no planner chatter) to a single
   worker subagent. The worker builds exactly what the spec asks and self-verifies
   with the repo's own checks.

5. Review (inside the worker). Still in its own context, the worker spawns the
   read-only review lanes — Codex debug + simplify — in parallel, then fixes or
   rebuts every finding itself. One round, hard cap, then re-verifies. Fable never
   sees the review traffic.

6. Buildout report. The worker hands Fable one compact report: every file touched,
   the coding decisions, and the disposition of each review finding (fixed /
   rebutted / residual). Summaries only — no code, no diffs. (The clean "what was
   built and why" narrative lives in the docs record; the report keeps the review
   dispositions because the gate needs them.)

7. Final gate. Fable spends its intelligence the second time: reads the diff once
   with fresh eyes, checks the plan's success criteria, tests whether the rebuttals
   hold and whether residuals matter, fixes small nits inline, re-runs the plan's
   validation. If it finds structural rework rather than nits, it writes a fresh
   spec and sends it back through the build step.

8. Docs + commit. A docs agent reconciles `.project/` to match what actually
   shipped, then Fable commits locally (code only — `.project/` is git-ignored).
   Never pushes, never opens a PR.

Throughout, docs observers run in parallel at the plan and build phases so doc
upkeep never blocks the build — at most one docs worker per repo at a time.
