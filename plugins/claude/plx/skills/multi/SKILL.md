---
name: multi
description: Run the same task on several user-named models in parallel, then synthesize one answer. Use only when the user invokes Multi.
argument-hint: "<task> using <model> <effort>, <model> <effort>, ..."
disable-model-invocation: true
user-invocable: true
---

# /plx:multi

Send one task, unchanged, to every model the user names. Run them in parallel and
synthesize their answers yourself. Every lane gets the same brief; do not split the
task into lenses or shards.

## Parse the request

Separate the task from the model list. Each entry is a model plus an optional effort;
missing effort means `medium`. Resolve natural names to an exact ID and engine:

| User says | Model ID | Engine |
| --- | --- | --- |
| astra 6, gpt-6 astra | `gpt-6-astra` | `codex` |
| sol, 6.1 sol, gpt-6.1 sol | `gpt-6.1-sol` | `codex` |
| luna, gpt-6 luna | `gpt-6-luna` | `codex` |
| opus 5.5, opus | `claude-opus-5-5` | `claude` |
| sonnet 5.5, sonnet | `claude-sonnet-5-5` | `claude` |
| haiku 5.5, haiku | `claude-haiku-5-5` | `claude` |
| fable 5.1, fable | `claude-fable-5-1` | `claude` |
| grok, grok 4.7 | `grok-4.7` | `grok` |
| gemini | `auto` | `gemini` |

Any other `gpt-*` ID runs on `codex`, `claude-*` on `claude`, `grok-*` on `grok`, and
`gemini-*` on `gemini`; pass it through unchanged. Gemini takes no effort; drop it.
Devin is not supported here (it requires full access). If a name is ambiguous or
unknown, ask before launching. Ignore model names that are only task content.

## Run

Note `git status` first. In a fresh temp directory `<tmp>`, write `<tmp>/brief.md`
with the task, preserving the user's wording and constraints. Drop the routing wording
(model list, "in parallel"). Add only necessary context or paths; keep your own
analysis out. Ask each model to return its answer, supporting evidence, and
uncertainty.

Use the packaged helpers on PATH. Launch every lane in one message, each in the
background, with a distinct `<lane>` (the model ID plus effort):

```
plx-engine --engine <engine> --mode ro --repo <repo> \
  --prompt-file <tmp>/brief.md --model <model> --effort <effort> \
  --out <tmp>/<lane>.md --log <tmp>/<lane>.log
```

Omit `--effort` for Gemini. Every lane is read-only, including models from your own
lab. If the host sandbox blocks an engine's network or keychain access, disable the
Bash sandbox for that wrapper call only; the engine's own sandbox stays active.

## Synthesize

Wait for every lane. If one fails, report its error and continue with the rest; do not
substitute another model. Then report:

1. **Answer:** the best-supported conclusion, verified directly where it matters.
2. **Agreement:** what every model agreed on.
3. **Disagreement:** where they differ, attributed by model, with each side's reasoning.
4. **Uncertainty:** what remains unresolved.

Weight evidence over vote count. Confirm afterward that `git status` is unchanged, then
delete `<tmp>`.
