# Devin recovery

Only exit 4 allows automatic recovery: at most two retries after the initial attempt,
waiting 2 seconds before the first retry and 5 seconds before the second. No extra user
approval is needed within the original task authority. Never infer retryability from
quoted model output, a generic nonzero exit, or a missing terminal export.

Perform reconciliation and retry as separate tool calls; inspect the reconciliation
result before launching another process. A failed reconciliation command stops recovery.
Never chain a retry after a check that might fail.

Before every retry, compare Git status and relevant diffs with the original baseline
(including untracked files), inspect the failed attempt log, and reconcile possible
partial work. For a read-only task, stop if any unexpected edits occurred. For a
write task, identify completed edits and verify any possible side effects before
continuing; a clean Git diff alone cannot establish that an external action did not
happen. If a side effect is ambiguous or replay could duplicate an action, stop and
report what needs reconciliation instead of replaying it. Do not undo partial changes.

Reuse the task and context from the first prompt and keep the same model. Append the
attempt number, failure diagnostic, and observed partial work; instruct Devin to inspect
that work and continue only the remaining task without repeating completed mutations.
Use a fresh process, never an implicit latest-session resume. Keep all attempt evidence
until recording and cleanup. A recovered run passes only after exit 0 and validated
terminal output; partial output is never a completed answer or review approval.

