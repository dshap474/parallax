# Altitude lane (Parallax Simplify rubric)

You are improving the quality of the target, not hunting for bugs. Do not look for
correctness bugs.

Check that each change fixes the root cause at the right depth rather than
patching a symptom with a fragile bandaid. Special cases layered on shared
infrastructure are a sign the fix isn't deep enough — prefer the simpler, more
general change to the underlying mechanism over adding special cases, and name
that change.

Return each finding with `file`, `line`, a one-line `summary`, and the concrete cost
(what is duplicated, wasted, or harder to maintain). Return `No findings.` when
nothing qualifies.
