---
name: agents-memory
description: Bootstrap or repair a repo's agent-docs setup — classify the root AGENTS.md and create/rewrite/refresh it from repo evidence (Project Memory preserved byte-for-byte), mirror CLAUDE.md as a symlink, and keep .project/ git-ignored. Idempotent; say "dry run" to preview.
argument-hint: "[repo path] [dry run]"
disable-model-invocation: true
user-invocable: true
---

# /plx:agents-memory — bootstrap the project docs system

You are the Parallax orchestrator (Fable). This skill brings a repo's agent-docs control
plane into canonical shape: a root `AGENTS.md` grounded in repo evidence, a `CLAUDE.md`
symlink mirror, and a git-ignored `.project/` substrate that agents populate during real
work. It is idempotent — re-running it on an unchanged repo produces zero diffs.

This skill is self-contained except for the canonical `AGENTS.md` template, which it
loads via `plx-skill --ref agents-memory/AGENTS.template` (a `bin/` tool on your PATH, not a path
pointer — the same mechanism `/plx:dev` uses for its spec template).

## Scope & stop rules

- **Root only.** You manage exactly one file: the repo-root `AGENTS.md`. Nested
  `AGENTS.md` files are user-authored — never classify, rewrite, or create them. (The
  mirror step still gives them `CLAUDE.md` symlinks; mirroring is content-agnostic.)
- **Project repos only.** If the target resolves to a global config dir (`~/.claude`,
  `~/.codex`) or `$HOME` itself, stop and say so.
- **Init writes only the contract.** Your writes are limited to: the root `AGENTS.md`,
  the root `CLAUDE.md` replacement in the migration case, a `.gitignore` fix, and
  symlinks via `plx-link-claude`. You do not seed `.project/` content — under this schema
  main agents write `.project/` docs directly during real work (no docs subagent), so
  leave those surfaces for first use.
- **Never invent.** Every command, boundary, and ownership claim in the generated file
  must be backed by repo evidence (manifests, scripts, layout, configs, existing docs).
  Weak evidence → inspect more; still weak → drop the claim.

## Modes

- **apply** (default): classify, write, gitignore, mirror, report.
- **dry-run** (user says "dry run", "preview", or "what would change"): classify and
  report what would change. Write nothing, dispatch nothing.

## Bootstrap

- Resolve the absolute repo root — the path given in the arguments, else
  `git rev-parse --show-toplevel`. Call it `<repo>`.
- Note `git status --short` so pre-existing edits aren't attributed to this run.
- Load the canonical template once: run `plx-skill --ref agents-memory/AGENTS.template` (a `bin/`
  tool on your PATH). Classification and writing both depend on it.
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
(`rm CLAUDE.md && ln -s AGENTS.md CLAUDE.md`). If both exist as regular files with
materially different content, stop and ask the user which is authoritative; if
identical, keep `AGENTS.md` and replace `CLAUDE.md` with the symlink yourself.

Classify into exactly one bucket:

- **current** — section model matches the canonical template (loaded at bootstrap) AND
  content still matches the checkout. Skip; no write.
- **empty** — exists but holds nothing durable (whitespace, a title, placeholder text).
  Populate as if missing.
- **incorrect** — section model, fixed-section wording, or memory section is missing or
  wrong — or the body is written as description rather than instruction (prose that
  explains the repo instead of directing the agent). Rewrite: salvage real content into
  the canonical sections as directives, drop boilerplate.
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
never by this skill.

### 3 — Write the canonical root AGENTS.md

Use the template loaded at bootstrap. It carries the section model, the verbatim
fixed-section bytes, the variable-section generation guidance, and the content
discipline. Author the root `AGENTS.md` to it:

- Emit the **fixed sections** (Runtime Rules and the Project Memory seed)
  **verbatim** — byte-for-byte, never paraphrased.
- Generate the **variable sections** (`# <repo name>` and Codebase Rules) from repo
  evidence, following the template's per-section guidance and content discipline.
- Splice the preserved Project Memory body (§2) under the final section, unchanged; if it
  was empty, use only the template's seed line.

After writing, re-classify the file: it must come out **current**. If it doesn't, that
is a defect — fix the file before reporting.

### 4 — Keep .project/ git-ignored

`.project/` is durable project memory but stays out of version control (local-only). If
`.gitignore` does not ignore it, add a `.project/` line in apply mode and
report the exact change. If the repo already has `.project/` files under git tracking,
do not untrack them yourself — surface it in the report and let the user decide
(`git rm -r --cached .project/` rewrites their index). Do not pre-create empty
`.project/` directories; agents create each surface on first write during real work.

### 5 — Mirror CLAUDE.md

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
  <when written: sections added/absorbed/dropped, description rewritten as directives, decision-table rows changed — each with its evidence>
Project Memory: preserved (<n> entries) | initialized | blocked: memory drift
.gitignore: ok | fixed: <change> | would fix: <change>
Mirror: <created>/<relinked>/<skipped>/<blocked> — <blocked paths, if any>
Idempotency: re-classified current ✓
```

In dry-run, the same shape with would-be actions. If nothing would change, keep it to
three lines: mode, `AGENTS.md: current — no write`, mirror/gitignore status.

Target:

$ARGUMENTS
