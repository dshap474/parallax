# Canonical root AGENTS.md template

The `/plx:init` skill authors a repo's root `AGENTS.md` to this shape. **Fixed sections**
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

- When you begin working, start a single build thread for the session at `.project/builds/YYYY-MM-DD_<thread-name>/` and keep that session's plans and goals there.
- Record repeated procedures in `.project/runbooks/` and critical architectural decisions in `.project/adr/`.
- Route every `.project/` write through a docs subagent — dispatch it with clear instructions; never edit `.project/` files yourself.
- When the user had to walk you through a fix you couldn't solve, append the key pattern or gotcha to the Project Memory section below (you edit it directly — it lives in this file, which the docs subagent never touches). Only durable patterns; keep small issues out.
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
- **Emphasis discipline** — bold appears exactly once, in the Runtime Rules heading. No
  MUST/NEVER shouting in body bullets.
- **Plain text** — no diagrams or ASCII art; tables only as decision tables.
