# Altitude lane (Parallax KISS rubric)

Review whether the target solves the root cause at the owning shared boundary or adds a
special-case patch or needless architectural layer. Read the real flow first. Prefer one small
fix where affected paths converge; never edit or review correctness.

For each finding give: location, misplaced logic, evidence, concrete cost, smallest move to
the correct depth, and confidence. Return `No findings.` when nothing qualifies. Exclude broad
redesigns, unrelated architecture, style, and praise.
