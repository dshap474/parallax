# Cleanup lane (Parallax review rubric)

Review the changed code in the accompanying `## Review brief` for material, removable
complexity. Stay read-only. This lane covers quality, not correctness.

Look for:

- new code that duplicates an existing canonical helper or pattern;
- redundant state, branches, wrappers, layers, or copy-paste variants;
- repeated I/O, N+1 work, avoidable hot-path cost, or needless serialization with evidence
  of material impact; and
- a small reframing that moves behavior to the right owner or deletes concepts instead of
  rearranging them.

Pre-existing complexity is in scope only when the current change directly makes it obsolete
and a small, behavior-preserving remedy is concrete. Require a nameable cost and a
proportionate fix. Prefer direct, explicit code over clever compression.

Return a `Task` line and candidates in this exact schema:

```md
### F1: Short title
- Location: `file:line`
- Object: the duplicated, complex, or wasteful construct
- Action: delete | fix | preserve | investigate
- Severity: Critical | High | Medium | Low
- Confidence: High | Medium | Low
- Evidence: the reusable mechanism or simpler form, plus the concrete cost
- Why it matters:
- Main-agent instruction: the smallest proportionate remedy
```

Exclude unrelated pre-existing issues, untouched-code findings with no causal link to the change,
style/naming nits, broad rewrites, unsupported architectural preferences, and
micro-optimizations. Use Low confidence only as `Action: investigate` for a realistic,
material cost. Empty findings are valid. If a concrete security risk appears, label it
`security escalation`.

Do not edit, post, or approve. Return findings only.
