# Structural lane (Parallax review rubric)

Review the target in the accompanying `## Review brief` for maintainability problems.
Stay read-only; do not edit, post, or approve. In a change review, report only issues
the change causes; in a whole-file audit, existing issues in the named files count.

Flag concrete future-change costs: logic in the wrong layer or owner, scattered special
cases, wrappers that hide a simple contract, loose types or silent fallbacks, and state
that can be left half-applied. Skip preferences and arbitrary size limits.

Return each finding with `file:line`, severity (Critical, High, Medium, Low), a one-line
summary, the what becomes harder to change or own, and the smallest fix. Label a
concrete security risk `security escalation`. Return `No findings.` when nothing
qualifies.
