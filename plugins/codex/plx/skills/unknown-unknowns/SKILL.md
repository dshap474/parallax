---
name: unknown-unknowns
description: Explore blind spots, alternatives, and understanding of the current work. Implementation planning belongs to Plan.
argument-hint: "<what you're working on, and where you are with it>"
---

# $plx:unknown-unknowns

Surface gaps that could change the user's work. Search the repository, research external
facts when useful, ask focused questions, and produce artifacts yourself. Do not launch
engine lanes or subagents; no preflight is needed.

Resolve `<plugin-root>` from this loaded `SKILL.md` path by removing
`/skills/unknown-unknowns/SKILL.md`. Use the packaged helpers in `<plugin-root>/bin/`.

Resolve `<repo>` with `git rev-parse --show-toplevel`. Read `.project/VISION.md` if it
exists and preserve its constraints; never edit it. Use the existing build thread for
persistent artifacts, or `.project/builds/YYYY-MM-DD_<thread-name>/` for a new effort.

Infer the user's experience and phase from the request: exploring, about to implement,
mid-implementation, or done and shipping. Ask one focused question if that context is
missing and would affect the approach.

Distinguish facts already known, questions the user recognizes, unstated criteria they
would recognize on sight, and issues they have not considered. Name the gaps you target
and choose the useful techniques below. Read only the references for the techniques you
select. Use the smallest useful response or artifact; honor requested formats.

| Need | Technique |
| --- | --- |
| New to the domain or codebase | [Blindspot pass](references/blindspots.md) |
| Scope or taste needs exploration | [Brainstorm or prototype](references/brainstorm.md) |
| An existing example gets it right | [Reference extraction](references/reference.md) |
| A design ready for implementation and critique | Hand off to `$plx:plan` |
| A settled plan entering implementation | [Implementation notes](references/implementation-notes.md) |
| Completed work needing stakeholder understanding | [Pitch and explainer](references/explainer.md) |
| Uncertainty about what changed | [Quiz](references/quiz.md) |

For a handoff, supply a paste-ready invocation carrying the relevant discoveries.
Leave the implementation plan to its owning skill.

## Return

Report the gaps examined, discoveries, artifact paths, and an improved next prompt or
skill invocation. Keep temporary runtime state out of the repository. Before every
handled return, record the host-only run:

```
<plugin-root>/bin/plx-eval finish --skill unknown-unknowns --host codex --repo <repo> \
  --outcome <pass|fail|partial|aborted> --verification <pass|fail|not-run> \
  || echo "plx-eval finish failed (non-fatal)" >&2
```

Recorder failure is non-fatal.
