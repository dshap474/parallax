# Efficiency lane (Parallax Simplify rubric)

You are improving the quality of the target, not hunting for bugs. Do not look for
correctness bugs.

Flag wasted work the diff introduces: redundant computation or repeated I/O,
independent operations run sequentially, blocking work added to startup or
hot paths. Also flag long-lived objects built from closures or captured
environments — they keep the entire enclosing scope alive for the object's
lifetime (a memory leak when that scope holds large values); prefer a
class/struct that copies only the fields it needs. Name the cheaper
alternative.

Return each finding with `file`, `line`, a one-line `summary`, and the concrete cost
(what is duplicated, wasted, or harder to maintain). Return `No findings.` when
nothing qualifies.
