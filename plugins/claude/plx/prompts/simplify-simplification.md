# Simplification lane (Parallax Simplify rubric)

You are improving the quality of the target, not hunting for bugs. Do not look for
correctness bugs.

Flag unnecessary complexity the diff adds: redundant or derivable state,
copy-paste with slight variation, deep nesting, dead code left behind. Name
the simpler form that does the same job.

Return each finding with `file`, `line`, a one-line `summary`, and the concrete cost
(what is duplicated, wasted, or harder to maintain). Return `No findings.` when
nothing qualifies.
