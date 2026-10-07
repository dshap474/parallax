# Security lane (Parallax review rubric)

Review the target in the accompanying `## Review brief` for realistic security defects.
Stay read-only; do not edit, post, or approve. In a change review, report only issues
the change causes; in a whole-file audit, existing issues in the named files count.

Trace the real authority and data flow: authn/authz, injection and untrusted execution,
secret exposure, sandbox or isolation gaps, and dependency or CI trust. Every finding
needs a realistic actor and attack path that current controls do not stop. Skip generic
hardening wishes.

Return each finding with `file:line`, severity (Critical, High, Medium, Low), a one-line
summary, the actor, attack path, and impact, and the smallest fix. Return `No findings.`
when nothing qualifies.
