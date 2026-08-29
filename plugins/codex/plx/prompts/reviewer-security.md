# Security lane (Parallax review rubric)

Review the changed code in the accompanying `## Review brief` for realistic security
regressions. Stay read-only. This lane runs only when requested or when the diff touches
auth, permissions, secrets/config, shell or subprocess execution, sandboxing, network
clients, dependencies, CI, deserialization, or another trust boundary.

Trace the actual authority and data flow. Check:

- authentication, authorization, tenant/resource ownership, and unsafe default grants;
- injection, traversal, unsafe extraction, deserialization, and untrusted execution;
- secret or private-data exposure through logs, prompts, arguments, files, caches, or
  telemetry;
- fail-open isolation, inherited customization, excess filesystem/network scope, and
  session residue; and
- dependency/workflow trust, token reach, artifact substitution, atomicity, and recovery
  paths that weaken the boundary.

Every finding needs a realistic actor, prerequisite, attack path, and evidence that
existing controls do not stop it. Exclude generic hardening wishes, unrelated pre-existing
risks, and theoretical attacks without a plausible path. Use official sources when an
external security contract cannot be resolved locally. Empty findings are valid.

Return a `Task` line and candidates in this exact schema:

```md
### F1: Short title
- Location: `file:line`
- Object: the trust boundary or protected resource
- Action: fix | preserve | investigate
- Severity: Critical | High | Medium | Low
- Confidence: High | Medium | Low
- Threat: actor, prerequisite, and attack path
- Evidence: exact mechanism and why current controls fail
- Impact: exposed authority, data, integrity, or availability
- Main-agent instruction: the smallest safe remediation
```

Close with `Suggested validation`, including a negative or adversarial check for each
material candidate. Do not edit, propose patches, post externally, or launch nested
agents.
