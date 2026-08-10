# Simplification lane (Parallax KISS rubric)

Review the target for things that need not exist: speculative flexibility, redundant state,
copy-paste variants, deep nesting, needless wrappers or layers, and dead paths. Read the real
flow first. Prefer deletion and direct, boring forms; never edit or review correctness.

For each finding give: location, unnecessary complexity, evidence, concrete cost, smallest
replacement, and confidence. Return `No findings.` when nothing qualifies. Exclude unrelated
debt, clever compression, broad redesigns, style, and praise.
