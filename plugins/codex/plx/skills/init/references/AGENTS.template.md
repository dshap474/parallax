# Canonical root AGENTS.md template

The `$plx-init` skill authors a repo's root `AGENTS.md` to this shape. **Fixed sections**
are emitted verbatim — byte-for-byte, never paraphrased. **Variable sections** are
generated from repo evidence per the guidance in each. The section order is exact, and
`## Project Memory` is always the final section.

Section model, in this exact order:

1. `# <repo name>`
2. `## **IMPORTANT:** Runtime Rules`
3. `## Codebase Rules`
4. `## Project Memory (User and Agent Append-Only)`

---

## Fixed sections — emit these bytes verbatim, do not paraphrase

Runtime Rules:

```markdown
## **IMPORTANT:** Runtime Rules
*Rules you must follow at turn end*

**Memory**
When the user had to walk you through a fix you couldn't solve, record the durable lesson once solved — reusable patterns, constraints, non-obvious gotchas, not one-offs. Directory-specific → nearest `AGENTS.md`; repo-wide → Project Memory below; you edit memory directly.

**Project Docs** — live under `.project/`; dated records take a `YYYY-MM-DD_` prefix. Write these yourself; there is no docs subagent. Prefer a no-op over weak docs — keep every update narrow to what the session actually touched; never create docs sprawl from thin signals.
- `builds/<thread>/` — one thread per session; plans, notes, working docs for the active effort
- `adr/` — critical architectural decisions
- `runbooks/` — repeatable procedures
- `architecture/` — durable subsystem models
- `notes/` — durable cross-cutting observations
- `security/` — current posture (`security/threat-model.md`) plus dated audit reports under `security/reports/`

Two history models: current-state surfaces (`architecture/`, `runbooks/`, `security/` posture) describe the system as it is now — edit them in place to match reality. Append-only surfaces (`builds/`, `adr/`, `notes/`, dated `security/reports/`) are never rewritten — supersede a stale record with a `Superseded by: <link>` line or a new dated one. At a build/session close, reconcile only the current-state surfaces to final state.

Inside a build folder: keep a `README.md` index (one line per file + `Status:` active/shipped/archived) and name files `<ROLE>_<slug>.md` (ROLE ∈ PLAN/NOTES/AUDIT/HANDOFF/REVIEW/REF); only the README is maintained, the rest is append-only. At close, distill durable decisions → `adr/`, procedures → `runbooks/`, set `Status: archived`, never delete.
```

Project Memory seed line (used only when the captured body is empty — initialization, not modification):

```markdown
- Use this section for durable repo-wide memory: gotchas, invariants, and facts agents must know before working here. Entries are append-only — add new ones; never rewrite or delete existing ones.
```

---

## Variable sections — generate from evidence

- `# <repo name>` — the repo's name, no slogan.
- `## Codebase Rules` — imperative routing and boundary rules generated from repo evidence:
  where each kind of work belongs and what to avoid. Open with 1–3 rules in imperative voice
  ("Route production work through X → Y → Z; do not skip layers", "Put reusable shared
  mechanics in `packages/platform` only when something is needed twice", "Never put Z here; it
  belongs in W"). Add a decision table (`| When the task is about... | Work in... | Avoid... |`,
  3–7 rows) only when the repo has real routing ambiguity; omit it otherwise. No layout prose,
  no file inventories, no command lists — those are `.project/` material or the agent's to
  discover at runtime.

## Content discipline for the variable sections

- **Instructive voice, always** — every line is an instruction an agent can follow or violate.
  No passive voice, no text that merely describes how things are. "Never validate inside domain
  code" beats "validation happens at the boundary". When salvaging existing content, rewrite
  description into the directive it implies; a line that cannot be rewritten as an instruction
  belongs in `.project/` docs, not here.
- **Operate test** — every line must change agent behavior. Purely descriptive lines get dropped
  or left to `.project/` docs.
- **Single home** — don't restate what the README or `.project/` docs own. `AGENTS.md` instructs;
  docs describe.
- **Emphasis discipline (variable sections)** — no bold and no MUST/NEVER shouting in the
  sections you generate. The fixed Runtime Rules block carries its own bold sub-labels
  (`**Memory**`, `**Project Docs**`) verbatim; don't add more.
- **Plain text** — no diagrams or ASCII art; tables only as decision tables.
