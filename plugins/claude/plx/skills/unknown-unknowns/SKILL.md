---
name: unknown-unknowns
description: Surface the user's unknowns — blindspot passes, brainstorms and throwaway prototypes, reference extraction, implementation notes, pitch/explainer docs, and comprehension quizzes — picking the technique(s) that fit where the user is in the work. Pure orchestrator work with no engine lanes; full interviews and implementation plans hand off to /plx:goal-spec and /plx:plan.
argument-hint: "<what you're working on, and where you are with it>"
disable-model-invocation: true
user-invocable: true
---

# /plx:unknown-unknowns

Surface gaps that could change the user's work. Search the repository, research external
facts when useful, ask focused questions, and produce artifacts yourself. Do not launch
engine lanes or subagents; no preflight is needed.

Use the packaged helpers on PATH.

Resolve `<repo>` with `git rev-parse --show-toplevel`. Read `.project/VISION.md` if it
exists and preserve its constraints; never edit it. Use the existing build thread for
persistent artifacts, or `.project/builds/YYYY-MM-DD_<thread-name>/` for a new effort.

Infer the user's experience and phase from the request: exploring, about to implement,
mid-implementation, or done and shipping. Ask one focused question if that context is
missing and would affect the approach.

Distinguish facts already known, questions the user recognizes, unstated criteria they
would recognize on sight, and issues they have not considered. Name the gaps you target
and choose the useful techniques below, usually one or two.

| Need | Technique |
| --- | --- |
| New to the domain or codebase | Blindspot pass |
| Scope or taste needs exploration | Brainstorm or prototype |
| An existing example gets it right | Reference extraction |
| Material goal ambiguity or an autonomous run | Hand off to `/plx:goal-spec` |
| A design ready for implementation and critique | Hand off to `/plx:plan` |
| A settled plan entering implementation | Implementation notes |
| Completed work needing stakeholder understanding | Pitch and explainer |
| Uncertainty about what changed | Quiz |

For a handoff, supply a paste-ready invocation carrying the relevant discoveries.
Leave the full interview and implementation plan to their owning skills.

## Techniques

For a blindspot pass, inspect prior art, relevant modules and conventions, historical
attempts, and known pitfalls. Explain the concepts needed to judge quality. Rank the
questions worth asking by their effect on the work and describe what good looks like.

For brainstorming, inspect the repo and offer distinct approaches from cheapest to most
ambitious, with a recommendation. For visual exploration, build one self-contained HTML
prototype with fake data and several distinct directions. After the user reacts, record
the criteria revealed by their choices. Save useful prototypes and criteria in the thread.

For references, read the supplied code, site, docs, or diagram; ask for a pointer if
missing. Inspect underlying code when available. Extract the desired behavior, structure,
and edge-case handling into a short contract the user can confirm.

For implementation notes, maintain `implementation-notes.md` in the thread during the
active implementation session. Under Deviations, record what was planned, what was found,
and what changed. Continue only for local, reversible choices that preserve scope,
behavior, and locked invariants; ask about material departures. Review deviations with
the user at session end.

For a pitch or explainer, create one self-contained Markdown or HTML document in the
thread. Lead with a demo, explain the decisions from the reader's starting point, and
cover likely failure questions. Integrate relevant spec, prototype, and implementation
notes into the explanation.

For a quiz, create an HTML report in the thread. Explain what changed and how it interacts
with existing code, then quiz the material behavior, edge cases, and interactions with
answers hidden until revealed. Encourage the user to resolve misunderstandings before merging.

## Return

Report the gaps examined, discoveries, artifact paths, and an improved next prompt or
skill invocation. Keep temporary runtime state out of the repository. Before every
handled return, record the host-only run:

```
plx-eval finish --skill unknown-unknowns --host claude --repo <repo> \
  --outcome <pass|fail|partial|aborted> --verification <pass|fail|not-run> \
  || echo "plx-eval finish failed (non-fatal)" >&2
```

Recorder failure is non-fatal.
