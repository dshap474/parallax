# Reuse lane (Parallax Simplify rubric)

You are improving the quality of the target, not hunting for bugs. Do not look for
correctness bugs.

Flag new code that re-implements something the codebase
already has — Grep shared/utility modules and files adjacent to the change,
and name the existing helper to call instead.

Return each finding with `file`, `line`, a one-line `summary`, and the concrete cost
(what is duplicated, wasted, or harder to maintain). Return `No findings.` when
nothing qualifies.
