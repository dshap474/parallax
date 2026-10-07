---
name: gemini
description: Single-engine Gemini CLI passthrough for questions, reviews, plans, and explicit file edits. Supports model selection; no shell execution or multi-model pipeline.
argument-hint: "<request> [model=<model>]"
disable-model-invocation: true
user-invocable: true
---

# /plx:gemini

Run the request through Gemini CLI only. Do not launch another engine or redo its answer.
Use the packaged helpers on PATH.

## Execute

Note `git status` first so you can attribute changes afterwards. In a fresh temp
directory `<tmp>`, write `<tmp>/prompt.md` with the task, preserving the user's
substantive wording and constraints. Drop routing wording such as "use a Gemini agent
to ..."; tell Gemini it is the requested agent and should do the task directly. Add
only necessary prior context, not your proposed solution.

Use `ro` for questions, reviews, and plans; use `rw` only for explicit editing requests.
The default model is `auto`; pass an explicit user model unchanged. Gemini has no
effort setting; say so if the user asks for one. Run it in the background for long calls:

```text
plx-engine --engine gemini --mode <ro|rw> --repo <repo> \
  --prompt-file <tmp>/prompt.md --model <model> --stdout
```

Gemini cannot run shell commands, including tests; disclose any unrun validation.
Never bypass a failed sandbox.

On failure, return `[PLX:GEMINI FAILED]` with the diagnostic and any partial changes.
For exit 3, direct the user to authenticate with `gemini` or set `GEMINI_API_KEY`.
Do not retry with another engine or substitute a host answer.

## Finish

On success, return Gemini's final output verbatim, then diff statistics for this run
only and any validation limitation. Delete `<tmp>`.

Request:

$ARGUMENTS
