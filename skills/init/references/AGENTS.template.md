# Canonical root AGENTS.md template

The `/plx:init` skill authors a repo's root `AGENTS.md` to this shape. **Fixed sections**
are emitted verbatim — byte-for-byte, never paraphrased. **Variable sections** are
generated from repo evidence per the guidance in each. The section order is exact, and
`## Project Memory` is always the final section.

Section model, in this exact order:

1. `# <repo name>`
2. `## **IMPORTANT:** Runtime Loop`
3. `## Codebase Architecture`
4. `## Docs`
5. `## Commands`
6. `## Execution`
7. `## Project Memory (User and Agent Append-Only)`

---

## Fixed sections — emit these bytes verbatim, do not paraphrase

Runtime Loop:

```markdown
## **IMPORTANT:** Runtime Loop
- At a logical checkpoint — a completed feature slice, a durable fix, a decision made, a stable point before changing direction — commit locally.
- If the session produced durable context (a changed system shape, a multi-session plan, an architectural decision, a reusable procedure), dispatch the docs worker per `## Docs`.
```

Docs:

```markdown
## Docs
- Read `.project/` freely — it is durable project memory, git-ignored and local-only. Never write it yourself: every `.project/` write goes through the Parallax docs worker (the `docs` agent shipped with the plx plugin).
  - Treat `.project/VISION.md` as user-owned and read-only: never edit, draft, or rewrite it. Flag a vision-vs-reality contradiction to the user as a flag only — never a proposed fix.
  - Read `.project/architecture/` before changing system shape.
  - Read `.project/builds/` when continuing a long-running buildout.
  - Read `.project/adr/` before revisiting a settled decision.
  - Follow `.project/runbooks/` for repeated operational procedures.
  - Check `.project/notes/` for non-canonical context that fits no other surface.
- Dispatch the docs worker with a compact Docs Impact Envelope — phase, repo path, changed paths, artifact paths, signal bits — never a prose recap. Expect exactly one status line back (`DOCS_OK: ...` or `DOCS_BLOCKED: ...`) and no prose report; inspect the worktree for detail.
- Run at most one docs worker per repo at a time.
```

Project Memory seed line (used only when the captured body is empty — initialization, not modification):

```markdown
- Use this section for durable repo-wide memory: gotchas, invariants, and facts agents must know before working here. Entries are append-only — add new ones; never rewrite or delete existing ones.
```

---

## Variable sections — generate from evidence

- `# <repo name>` — the repo's name, no slogan.
- `## Codebase Architecture` — open with 1–3 boundary directives in imperative voice
  ("When the task involves X, work in Y", "Never put Z here; it belongs in W"). Add a
  decision table (`| When the task is about... | Work in... | Avoid... |`, 3–7 rows)
  only when the repo has real routing ambiguity; omit it otherwise. No layout prose, no
  file inventories — that is `.project/architecture/` material.
- `## Commands` — real commands only, verified against manifests, scripts, and CI:
  bootstrap, primary local validation, single-test. Omit anything you cannot evidence.
- `## Execution` — imperative operating rules and code-authoring policy the repo itself
  evidences (lint config, existing conventions, CI gates): "validate at boundaries",
  "imports at top of file", "prefer X over Y". Drop description; keep directives.

## Content discipline for the variable sections

- **Instructive voice, always** — every line in `AGENTS.md` is an instruction for how an
  agent must act, written as a directive the agent can follow or violate. No passive
  voice, no text that merely describes how things are. "Never validate inside domain
  code" beats "validation happens at the boundary"; "When the task involves billing,
  work in `services/billing`" beats "this directory handles billing". When salvaging
  existing content, rewrite description into the directive it implies; a line that
  cannot be rewritten as an instruction belongs in `.project/` docs, not here.
- **Operate test** — every line must change agent behavior. Purely descriptive lines get
  dropped or left to `.project/` docs.
- **Single home** — don't restate what the README or `.project/` docs own. `AGENTS.md`
  instructs; docs describe.
- **Emphasis discipline** — bold appears exactly once, in the Runtime Loop heading. No
  MUST/NEVER shouting in body bullets.
- **Plain text** — no diagrams or ASCII art; tables only as decision tables.
