# Code (Stage 3)

Implement one task from its spec. The writer is whichever engine `config/parallax.yaml` assigns to the `code` role for the active pipeline:

- **Claude writer (default):** in solo/team pipelines the orchestrator implements directly with `Edit`/`Write`. In pipelines that delegate (e.g. ultra), a fresh `plx:claude-worker` subagent implements from the spec alone.
- **Non-Claude writer:** when `code` is `codex`/`grok`, the spec is handed to `plx:codex-worker` / `plx:grok-worker`, which run the matching `*-rw.sh` wrapper (scoped write to the target repo only); the orchestrator then reviews the diff.

A delegated worker receives the **spec only** — no orchestrator analysis, no review history — so the first pass stays uncontaminated and the orchestrator's context stays lean.

## Implement

- Build exactly what the spec says. Honor its interfaces, types, and names — do not redesign them.
- Touch only the files the spec lists; respect its "do NOT touch" boundaries.
- Reuse the helpers/utilities the spec names instead of writing new ones.
- Keep it minimal — no speculative abstraction, no options nothing calls.
- Follow the repo conventions the spec points to (`AGENTS.md` / `CLAUDE.md` / a sibling file).

Independent tasks run in parallel (one per task); dependent tasks run in order. For risky changes, work in a disposable `git worktree` and review the diff before merging.

## Self-verify

Run the spec's acceptance checks with the repo's own toolchain binaries — `.venv/bin/ruff`, `.venv/bin/pytest`, `npm test`, `cargo test`, etc. **Never `uv run` inside a sandbox.** Report what you ran and the result; do not invent new test harnesses.

## Output

The edits (or the diff, for a delegated/worktree writer) plus the acceptance-check results. Refine (Stage 4) and review (Stage 5) operate on this output.
