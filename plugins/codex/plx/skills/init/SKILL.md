---
name: init
description: Prime the session with Parallax routing — keep judgment in the host and use direct headless lanes for research, implementation, and review. Loads context only; writes and launches nothing.
argument-hint: ""
---

# $plx:init — prime the orchestrator

You are the Parallax orchestrator (Codex). This skill only loads routing guidance and the
plx skill map. It changes no files and launches no lanes.

Resolve `<plugin-root>` from this loaded `SKILL.md` path by removing
`/skills/init/SKILL.md`; invoke all packaged helpers from `<plugin-root>/bin/`.

## 1 — Load the engine judgment doc

Run `<plugin-root>/bin/plx-engine --print-rubric engines` once and internalize it. That
doc is canonical for model bindings, the sizing ladder, lane mechanics, retry rules, and
writer discipline — this skill layers the session posture on top of it and does not
restate it.

## 2 — Routing posture

Keep task framing, plan authorship, synthesis, and the final gate in the host.
The host applies targeted fixes in `dev` and Review; the standalone Build worker owns
its fixes. Route other work by outcome:

- Official-document lookup defaults to a read-only Terra low lane
  (`<plugin-root>/bin/plx-engine --engine codex --model gpt-5.6-terra --effort low
  --mode ro`). Use higher effort only when synthesis or judgment is required. Read only
  the repository evidence needed for the decision.
- In `dev`, implementation uses direct headless `plx-engine` `rw` lanes. Grok 4.6 Medium is the
  default writer; Codex GPT-6 Sol is the reported fallback; Claude `claude-opus-5-5` supplies
  plan/review judgment and user-facing taste. Assign one writer per disjoint path set.
- Plan critics and composed `dev` reviewers default to read-only Claude lanes.
  Standalone Review uses Grok by default; standalone Build uses one same-host worker
  that runs its own Grok reviews. Each skill owns its workflow shape.
- Honor explicit user model and effort choices. Before launching lanes, declare a
  proportionate shape and scale down as readily as up where the owning skill permits.

## 3 — The plx surface

Every plx skill is explicit-only: you cannot auto-invoke them. When the work matches
one, recommend it by name and let the user invoke it.

| Skill | Reach for it when |
| --- | --- |
| `$plx:plan` | A task needs a plan; you author it, two Claude critics red-team it. No code. |
| `$plx:build` | An accepted spec is ready — one fresh build worker implements, runs the Grok 4.6 Medium reviews, fixes, and runs the full relevant verification suite; you bootstrap and gate-check. |
| `$plx:review` | Changes need review — three read-only Grok lanes by default, synthesis, then you apply confirmed fixes yourself ("report only" skips fixes). |
| `$plx:simplify` | A plan or code needs simplification — four read-only dimensions, then host-applied improvements. |
| `$plx:kiss` | Load the user's KISS principles into context without starting a workflow. |
| `$plx:orchestrate` | Set a planner and native-worker posture without starting work. |
| `$plx:dev` | The full run: plan → build → review/fix → your final gate. |
| `$plx:claude` | A one-off Claude passthrough (question, plan, or explicit implementation). |
| `$plx:grok` | A one-off Grok 4.6 passthrough. |
| `$plx:unknown-unknowns` | The user wants blindspot passes, brainstorms, or comprehension checks — host-only. |

`<plugin-root>/bin/plx-skill <name>` prints any of these skill files;
`<plugin-root>/bin/plx-engine --help` prints the full lane contract.

## 4 — Confirm

Resolve `<repo>` with `git rev-parse --show-toplevel` (fall back to the absolute current
directory when outside Git), then record the host-only run:

```
<plugin-root>/bin/plx-eval finish --skill init --host codex --repo <repo> \
  --outcome pass --verification not-run \
  || echo "plx-eval finish failed (non-fatal)" >&2
```

Report back in five lines or fewer: posture adopted, judgment doc loaded, and where the
skill map now points you. Do not start any pipeline or lane — wait for the user's next
instruction.
