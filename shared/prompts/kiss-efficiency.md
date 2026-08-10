# Efficiency lane (Parallax KISS rubric)

Review the target for unnecessary work: repeated computation or I/O, needless serialization,
eager or blocking work, retained objects, and optimization without evidence. Read the real
flow first. Prefer doing less with existing mechanisms; never edit or review correctness.

For each finding give: location, wasted work, evidence, concrete cost, smallest replacement,
and confidence. Return `No findings.` when nothing qualifies. Exclude hypothetical hot paths,
micro-optimizations, unrelated debt, style, and praise.
