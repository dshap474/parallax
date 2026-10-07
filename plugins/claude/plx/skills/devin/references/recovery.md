# Devin recovery

Retry only on exit 4. Wait a few seconds before each retry; no extra user approval is
needed within the original task authority.

Reconcile before every retry, as a separate step: compare `git status` with the start,
read the failed attempt log, and identify partial work. For a read-only task, stop if
anything was edited. For a write task, verify possible side effects; a clean diff does
not prove an external action didn't happen. If a side effect is ambiguous or replay
could duplicate an action, stop and report it. Do not undo partial changes.

Retry with the same prompt and model in a fresh process, appending the attempt number,
the diagnostic, and the observed partial work; tell Devin to continue only the remaining
task without repeating completed mutations. Partial output is never a completed answer.
