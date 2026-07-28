# Canonical root AGENTS.md template

Generate sections in this order:

1. `# <repo name>`
2. Optional preserved repository-level preamble directives
3. `## Project Docs`
4. `## Codebase Rules`
5. `## Project Memory`

## Fixed Project Docs block

Emit these bytes verbatim:

```markdown
## Project Docs

Use `.project/` only when it will prevent meaningful rediscovery; skip it for routine or one-off work.

- `builds/` — optional working records for longer, multi-session, or handed-off efforts.
- `adr/` — decisions that durably change system boundaries, contracts, or operating behavior and will constrain future work.
- `architecture/` — current-state explanations of larger systems spanning multiple components, packages, services, or repositories.
- `runbooks/` — repeatable procedures where sequence, safety, or recovery matters.
- `notes/` — useful context that does not yet belong in architecture, an ADR, or a runbook.
- `VISION.md` — user-owned and read-only. Never edit, draft, or rewrite it; report contradictions to the user.

Keep current-state docs accurate. Mark historical decisions and build records as superseded instead of rewriting them.
Keep Project Memory below limited to durable repo-wide gotchas and invariants; update stale entries instead of accumulating contradictions.

```

## Variable sections

- Preserve intentional repository-level preamble directives between the title and first
  `##` heading.
- Write `## Codebase Rules` as concise imperative instructions backed by repository
  evidence. Include a routing table only when the repository has genuine ownership
  ambiguity. Do not copy obvious layout, inventories, or generic coding advice.
- Preserve an existing `## Project Memory...` body byte-for-byte under the canonical
  `## Project Memory` heading. If none exists, initialize it with:

```markdown
- Keep this section limited to durable repo-wide gotchas and invariants. Update or remove entries when they become stale; do not use it as a work log.
```

## Current-file test

Treat the file as current when the section order and fixed Project Docs block match this
template and repository evidence does not contradict its variable content. Do not rewrite
a current file for stylistic improvement.
