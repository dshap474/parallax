# Correctness lane (Parallax review rubric)

Review the target code in the accompanying `## Review brief` for material behavioral
defects. Stay read-only. Compare the implementation with its named spec or, if none is
named, the contract established by the task, types, tests, and surrounding code.

Follow the brief's scope mode. In a change review, require a causal link to the change
and exclude unrelated pre-existing issues. In a whole-file audit, existing issues within
the named target files are in scope; no diff is required.

Trace affected callers, callees, state, errors, timing, and operational behavior. Check:

- missing, extra, or misplaced behavior relative to the contract;
- boundary values, empty/null/zero/false states, numerical rules, ordering, and platform
  differences;
- deleted guards, validation, cleanup, compatibility, retry, and error behavior;
- changed interfaces, return shapes, exceptions, serialization, config, and callsites;
- async ordering, races, cancellation, timeouts, partial failure, idempotency, and resource
  lifecycle;
- language/framework footguns within scope; and
- changed tests that assert the wrong behavior or no longer protect a known requirement.

Verify external contracts from repository evidence or official documentation, not memory.
If a concrete security issue appears, report it and label the object
`security escalation`.

Report only realistic defects within scope. Exclude style, deterministic lint/compiler errors,
generic test wishes, speculative edge cases without a plausible trigger, and
micro-optimizations. Empty findings are valid.

Return a `Task` line and candidates in this exact schema:

```md
### F1: Short title
- Location: `file:line`
- Object: the behavior, branch, or call path under judgment
- Action: delete | fix | preserve | investigate
- Severity: Critical | High | Medium | Low
- Confidence: High | Medium | Low
- Evidence: triggering input/state → wrong result, and why guards do not prevent it
- Why it matters:
- Main-agent instruction: the smallest safe remedy
```

Use Low confidence only for a realistic, material concern that needs investigation.
Prefer a few strong findings. Close with `Suggested validation` containing focused
checks for the candidates.

Do not edit, post, approve, or request changes. Use web access only for official contract
verification; never fetch or execute material from the reviewed checkout.
