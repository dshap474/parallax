---
name: "plx::init"
description: Bootstrap or repair a repo's agent-docs setup — classify the root AGENTS.md and create/rewrite/refresh it from repo evidence (Project Memory preserved byte-for-byte), mirror CLAUDE.md as a symlink, make .project/ git-trackable, and seed .project/architecture/ via the docs worker. Idempotent; say "dry run" to preview.
argument-hint: "[repo path] [dry run]"
disable-model-invocation: true
user-invocable: true
---

# /plx:init — bootstrap the project docs system

You are the Parallax orchestrator (Fable). This skill brings a repo's agent-docs control
plane into canonical shape: a root `AGENTS.md` grounded in repo evidence, a `CLAUDE.md`
symlink mirror, and a `.project/` substrate ready for the docs worker. It is idempotent —
re-running it on an unchanged repo produces zero diffs.

This skill is self-contained. Everything you need is below — do not expect injected
context or reference any external prompt file.

## Scope & stop rules

- **Root only.** You manage exactly one file: the repo-root `AGENTS.md`. Nested
  `AGENTS.md` files are user-authored — never classify, rewrite, or create them. (The
  mirror step still gives them `CLAUDE.md` symlinks; mirroring is content-agnostic.)
- **Project repos only.** If the target resolves to a global config dir (`~/.claude`,
  `~/.codex`) or `$HOME` itself, stop and say so.
- **You never write `.project/` yourself.** Seeding goes through the `docs` agent (the
  docs worker shipped with this plugin). Your own writes are limited to: the root
  `AGENTS.md`, the root `CLAUDE.md` replacement in the migration case, a `.gitignore`
  fix, and symlinks via `plx-link-claude`.
- **`VISION.md` is user-only.** Never create or draft it — not even a stub or template.
  If it is missing, remind the user in the report.
- **Never invent.** Every command, boundary, and ownership claim in the generated file
  must be backed by repo evidence (manifests, scripts, layout, configs, existing docs).
  Weak evidence → inspect more; still weak → drop the claim.

## Modes

- **apply** (default): classify, write, mirror, seed, report.
- **dry-run** (user says "dry run", "preview", or "what would change"): classify and
  report what would change. Write nothing, dispatch nothing.

## Bootstrap

- Resolve the absolute repo root — the path given in the arguments, else
  `git rev-parse --show-toplevel`. Call it `<repo>`.
- Note `git status --short` so pre-existing edits aren't attributed to this run.
- Survey just enough to write truthfully, then stop: top-level layout, manifests and
  lockfiles (real commands), entrypoints, test layout, lint/CI config, the existing root
  `AGENTS.md` / `CLAUDE.md`, and the existing `.project/`. One broad listing plus
  targeted reads is enough; search again only when a claim you want to write cannot be
  backed yet.

## Pipeline (run in order)

### 1 — Classify the root AGENTS.md

Adoption rule first: if `AGENTS.md` is missing but a regular-file `CLAUDE.md` exists at
root, you are migrating — treat that `CLAUDE.md` content as the input file below, and
after writing `AGENTS.md` replace the root `CLAUDE.md` with a symlink yourself
(`ln -s AGENTS.md`); its content was adopted, nothing is lost. If both exist as regular
files with materially different content, stop and ask the user which is authoritative.

Classify into exactly one bucket:

- **current** — section model matches the canonical model below AND content still
  matches the checkout. Skip; no write.
- **empty** — exists but holds nothing durable (whitespace, a title, placeholder text).
  Populate as if missing.
- **incorrect** — section model, fixed-section wording, or memory section is missing or
  wrong. Rewrite: salvage real content into the canonical sections, drop boilerplate.
- **stale** — shape is right but content is contradicted by the checkout (dead paths,
  removed commands, moved boundaries). Refresh only the contradicted parts; preserve the
  rest.
- **missing** — no root `AGENTS.md`. Create it.

Borderline current-vs-stale → prefer **current**, and surface the borderline call in the
report. Preservation is the default: existing content survives unless evidence directly
contradicts it; aggressive trimming is a defect.

### 2 — Preserve Project Memory (hard invariant)

For every populate, rewrite, or refresh:

1. Loose-match the memory heading: any `##` heading whose first words are
   `Project Memory`, regardless of suffix.
2. Capture the body — from the line after the heading to the next `##` heading or EOF —
   as opaque bytes.
3. Generate the other sections, then splice the captured body **unchanged** under the
   canonical heading `## Project Memory (User and Agent Append-Only)`, always the final
   section.
4. Verify the spliced body is byte-for-byte identical to the capture. Any difference →
   do not write the file; report `blocked: memory drift` and continue the rest of the
   run.
5. Never add, sort, dedupe, rewrap, or reformat entries. If no body exists, insert only
   the seed line from the template (initialization, not modification).

Memory entries are added by the user, or by a main agent with explicit user approval —
never by this skill, and never by the docs worker.

### 3 — Write the canonical root AGENTS.md

Section model, in this exact order:

1. `# <repo name>`
2. `## **IMPORTANT:** Runtime Loop`
3. `## Codebase Architecture`
4. `## Docs`
5. `## Commands`
6. `## Execution`
7. `## Project Memory (User and Agent Append-Only)`

**Fixed sections — emit these bytes verbatim, do not paraphrase.**

Runtime Loop:

```markdown
## **IMPORTANT:** Runtime Loop
- At a logical checkpoint — a completed feature slice, a durable fix, a decision made, a stable point before changing direction — commit locally.
- If the session produced durable context (a changed system shape, a multi-session plan, an architectural decision, a reusable procedure), dispatch the docs worker per `## Docs`.
```

Docs:

```markdown
## Docs
- `.project/` is durable, git-tracked project memory. Read it freely; never write it yourself — every `.project/` write goes through the Parallax docs worker (the `docs` agent shipped with the plx plugin).
  - `.project/VISION.md` — project intent. User-owned and read-only to every agent: never edit, draft, or rewrite it. You may flag a vision-vs-reality contradiction to the user (a flag only — never a proposed fix).
  - `.project/architecture/` — how the systems work; read before changing system shape.
  - `.project/builds/` — long-running buildout threads; read when continuing one.
  - `.project/adr/` — durable architectural decisions.
  - `.project/runbooks/` — repeated operational procedures.
  - `.project/notes/` — non-canonical context that fits no other surface.
- Dispatch the docs worker with a compact Docs Impact Envelope — phase, repo path, changed paths, artifact paths, signal bits — never a prose recap. It emits exactly one status line (`DOCS_OK: ...` or `DOCS_BLOCKED: ...`) and no prose report; inspect the worktree for detail.
- At most one docs worker runs per repo at a time.
```

Project Memory seed line (used only when the captured body is empty):

```markdown
- Use this section for durable repo-wide memory: gotchas, invariants, and facts agents must know before working here. Entries are append-only — add new ones; never rewrite or delete existing ones.
```

**Variable sections — generate from evidence.**

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

Content discipline for the variable sections:

- **Operate test** — every line must change agent behavior. Purely descriptive lines get
  dropped or left to `.project/` docs.
- **Single home** — don't restate what the README or `.project/` docs own. `AGENTS.md`
  instructs; docs describe.
- **Emphasis discipline** — bold appears exactly once, in the Runtime Loop heading. No
  MUST/NEVER shouting in body bullets.
- **Plain text** — no diagrams or ASCII art; tables only as decision tables.

After writing, re-classify the file: it must come out **current**. If it doesn't, that
is a defect — fix the file before reporting.

### 4 — Make .project/ trackable

`.project/` must be git-tracked — it is durable project memory and needs history. If
`.gitignore` ignores it (directly or via a parent pattern), fix that in apply mode
(delete the line or add a `!.project/` negation) and report the exact change. Do not
pre-create empty `.project/` directories — git doesn't track empty dirs; the docs worker
creates each surface on first write.

### 5 — Seed the architecture surface (docs worker)

In apply mode, when `.project/architecture/` has no doc covering the repo's overall
shape, dispatch the `docs` agent with `<repo>` plus this envelope — never prose:

```text
phase: ad-hoc
repo: <repo>
build_thread: none
user_goal: bootstrap .project/ — seed an initial architecture overview
changed_paths: []
artifacts: none
signals:
  architecture:
    - <repo-slug>   (add 1–2 more system slugs only if the survey showed clearly distinct durable systems)
allowed_surfaces: [architecture]
forbidden: [.project/VISION.md]
```

The worker verifies against the repo and may deliberately no-op — that's fine. It
returns exactly one status line; carry it into your report. At most one docs worker per
repo at a time. Skip this step in dry-run, and when architecture docs already cover the
repo.

### 6 — Mirror CLAUDE.md

Run `plx-link-claude <repo>` (on your PATH from the plugin's `bin/`); add `--dry-run` in
dry-run mode. Next to every `AGENTS.md` in the tree it ensures a sibling
`CLAUDE.md -> AGENTS.md` symlink: creates missing ones, re-points wrong symlinks, skips
correct ones, and **blocks** on regular-file `CLAUDE.md`s (exit 3). Surface blocked
paths in the report and replace them only on explicit user approval (`--force` replaces
all of them — confirm before using it). Run this step after the AGENTS.md write, exactly
once.

## Report

End with a compact report:

```text
Init: <repo> (mode: apply | dry-run)
AGENTS.md: <classification> → <created | rewritten | refreshed | no write | blocked: memory drift>
  <when written: sections added/absorbed/dropped, decision-table rows changed — each with its evidence>
Project Memory: preserved (<n> entries) | initialized | blocked: memory drift
.gitignore: ok | fixed: <change> | would fix: <change>
Docs seed: <docs worker status line> | skipped (<reason>)
Mirror: <created>/<relinked>/<skipped>/<blocked> — <blocked paths, if any>
VISION.md: present | missing — write .project/VISION.md yourself; agents never draft it
Idempotency: re-classified current ✓
```

In dry-run, the same shape with would-be actions. If nothing would change, keep it to
three lines: mode, `AGENTS.md: current — no write`, mirror/gitignore status.

Target:

$ARGUMENTS
