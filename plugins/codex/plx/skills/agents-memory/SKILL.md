---
name: agents-memory
description: Bootstrap or repair a repository's root AGENTS.md, mirror CLAUDE.md as a symlink, and keep optional local project memory under a git-ignored .project/. Use for new repositories, legacy agent-doc migrations, or stale root instructions; say "dry run" to preview. Idempotent on an unchanged repository.
---

# $plx:agents-memory

Bring one repository's agent-documentation control plane into the canonical shape without
creating `.project/` content. Preserve user-owned context, derive repository rules from
evidence, and prefer a no-op when the current file remains correct.

Load the canonical template once with
`<plugin-root>/bin/plx-skill --ref agents-memory/AGENTS.template`. Resolve
`<plugin-root>` from this loaded `SKILL.md` path by removing
`/skills/agents-memory/SKILL.md`.

## Boundaries

- Manage only the repository-root `AGENTS.md`, root migration inputs, `.gitignore`, and
  `CLAUDE.md` symlinks. Never rewrite or create nested `AGENTS.md` files.
- Stop on `$HOME`, `~/.claude`, or `~/.codex`.
- Never create `.project/` directories or documents. They are optional working memory
  created only when real work justifies them.
- Back every generated Codebase Rule with repository evidence. Drop unsupported claims.

## Modes

- **Apply** by default.
- **Dry run** when the user says "dry run", "preview", or "what would change". Inspect
  and report without writing.

## Workflow

1. Resolve the absolute repository root from the argument or
   `git rev-parse --show-toplevel`. Record `git status --short`.
2. Load the canonical template and inspect only enough repository evidence to assess the
   root instructions: top-level layout, manifests, commands, boundaries, existing
   `AGENTS.md` / `CLAUDE.md`, and `.project/`.
3. If root `AGENTS.md` is missing and root `CLAUDE.md` is a regular file, use
   `CLAUDE.md` as the migration input. If both are regular files with materially
   different content, stop and ask which is authoritative.
4. Classify the input:
   - **current** — it has the canonical section order and exact Project Docs block, and
     no rule is contradicted by the checkout. Do not rewrite it.
   - **legacy** — a root input exists but does not satisfy `current`. Migrate it.
   - **missing** — neither root input exists. Create `AGENTS.md`.
5. For `legacy` or `missing`, author the canonical shape:
   - Preserve intentional repository-level preamble directives between the title and
     first `##` heading.
   - Preserve evidence-backed repository instructions as concise imperative Codebase
     Rules. Refresh only claims contradicted by the checkout; do not churn wording for
     style.
   - Loose-match any `## Project Memory...` heading. Capture its body through EOF as
     opaque bytes and splice it unchanged under `## Project Memory`. If no body exists,
     use the template seed.
   - Verify the captured and spliced Project Memory bodies are byte-identical before
     writing. On drift, do not write `AGENTS.md`.
6. Ensure `.gitignore` contains `.project/`. Report already-tracked `.project/` files
   without untracking them.
7. Run `<plugin-root>/bin/plx-link-claude <repo>` once, adding `--dry-run` in dry-run
   mode. Regular-file `CLAUDE.md` conflicts remain blocked unless the root migration
   established that file as the authoritative input; never use `--force` without
   explicit approval.
8. Reclassify the result. A write is successful only when it is `current`; an immediate
   unchanged rerun must produce no write.

The skill never edits individual Project Memory entries. Agents working in the repository
may correct stale entries under the generated policy.

## Report

Return:

```text
Agents memory: <repo> (apply | dry-run)
AGENTS.md: <missing | legacy | current> → <created | rewritten | no write | blocked>
Project Memory: <preserved (n entries) | initialized | blocked: memory drift>
.gitignore: <ok | fixed | would fix | tracked files need user decision>
Mirror: <created>/<relinked>/<skipped>/<blocked>
Idempotency: <current ✓ | not established>
```

Target:

$ARGUMENTS
