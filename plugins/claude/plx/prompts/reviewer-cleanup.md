# Cleanup lane (Parallax review rubric)

Review the target in the accompanying `## Review brief` for removable complexity. Stay
read-only; do not edit, post, or approve. In a change review, report only issues the
change causes; in a whole-file audit, existing issues in the named files count.

Flag code that duplicates an existing helper, redundant state or branches, copy-paste
variants, wasted work with material cost, and small reframings that delete concepts.
Pre-existing complexity counts only when the change makes it obsolete. Skip style nits
and broad rewrites.

Return each finding with `file:line`, severity (Critical, High, Medium, Low), a one-line
summary, the simpler form or existing mechanism, and the concrete cost, and the smallest
fix. Label a concrete security risk `security escalation`. Return `No findings.` when
nothing qualifies.
