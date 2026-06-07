---
name: "plx::grok"
description: "[SCAFFOLD] Single-engine passthrough — Grok Composer 2.5 (headless). Answers, codes, or plans. Pending a write-probe: headless Grok editing is unverified. Not yet enabled."
argument-hint: "<question, coding task, or plan request>"
disable-model-invocation: true
user-invocable: true
---

# /plx:grok — single-engine passthrough (Grok Composer 2.5) (SCAFFOLD)

**STATUS: scaffold — not yet enabled. Blocked on a headless write-probe.**

Intended behavior: mirror `/plx:codex` but route through **Grok Composer 2.5** headless — spawn `plx:grok-worker`, which runs `${CLAUDE_PLUGIN_ROOT}/scripts/grok-rw.sh` (Bash sandbox disabled for that call). Answers a question, edits for a coding task, or writes a plan, with no review pipeline.

Why blocked: Grok **writing** was previously unsupported — background edit workers died with `AuthorizationRequired` (grok 0.2.16, interactive `acceptEdits`). The headless path (`grok -p "…" --always-approve --no-alt-screen`) may behave differently, and needs verifying before this command can edit safely. Two unknowns to resolve first:

1. the exact `-m` model id for "Composer 2.5", and
2. confirm `grok -p --always-approve` actually applies file edits (not just prints), via `grok-rw.sh` in a throwaway repo.

Read-only Grok (`grok-ro.sh` / `plx:grok-reviewer`) already works and is used in `ultra-dev` review lanes (and any pipeline configured with Grok review lanes).

Until enabled: use `/plx:codex` (working headless write) or `/plx:claude`.

Request:

$ARGUMENTS
