# How to use codex-app-client

Use this guide when you need to run Codex from an agent, script, shell command,
or Python program. The command-line entry point is `cxa`.

## Non-negotiable default: one-off requests are ephemeral

New threads are ephemeral by default. **Still pass `--ephemeral` explicitly for
a one-off request** so the intent remains visible and future-proof in agent
commands. This prevents Codex from saving a resumable session transcript under
`$CODEX_HOME/sessions` (normally `~/.codex/sessions`).

```bash
uv run cxa run \
  --cwd /absolute/path/to/the/target/project \
  --mode inspect \
  --ephemeral \
  --prompt "What is 1+1?"
```

Create a persistent thread only when you deliberately need to continue or
resume the same conversation later, using the explicit `--persistent` flag.

## Run location

If `cxa` is installed as a tool, invoke it directly from anywhere:

```bash
cxa doctor --cwd /absolute/path/to/the/target/project
```

Otherwise, run it from the repository root through this package's environment:

```bash
cd plugins/claude/plx/tools/codex-app-client
uv sync --all-extras --locked
uv run cxa doctor --cwd /absolute/path/to/the/target/project
```

`--cwd` is the project Codex will inspect or edit. Always pass the intended
absolute path. Codex discovers the applicable `AGENTS.md` files from that
location, so choosing the correct and narrowest useful working directory also
keeps context and token usage under control.

## Choose the correct mode

Use the least-powerful mode that can complete the task:

| Mode | Access | Use it for |
|---|---|---|
| `inspect` | Read-only, approvals denied | Questions, investigation, review, explanation |
| `edit` | Workspace writes, requests auto-reviewed | Requested code or file changes |
| `ci-edit` | Workspace writes, approvals denied | Non-interactive edits that must not pause for approval |

For questions such as “explain this code,” “find the bug,” or “what is 1+1,”
use `--mode inspect`.

Use `--mode edit` only when the caller explicitly wants Codex to modify files.

Full access is exceptional. It requires both `--sandbox full-access --unsafe`
and `CODEX_APP_CLIENT_UNSAFE=1`. Do not enable it merely to work around a
denied action.

## Common one-off commands

### Ask a read-only question

```bash
uv run cxa run \
  --cwd /absolute/path/to/project \
  --mode inspect \
  --ephemeral \
  --timeout 120 \
  --prompt "Explain what this repository does in five bullets."
```

### Ask Codex to make a change

```bash
uv run cxa run \
  --cwd /absolute/path/to/project \
  --mode edit \
  --ephemeral \
  --timeout 900 \
  --prompt "Fix the failing parser test. Preserve the public parser API and run the focused tests."
```

Even an editing request should normally be ephemeral when it is a single
self-contained task. File changes remain in the project; `--ephemeral` only
prevents the Codex conversation transcript from becoming a resumable thread.

### Pipe a prompt on stdin

```bash
printf '%s\n' "Summarize the applicable AGENTS.md instructions." \
  | uv run cxa run \
      --cwd /absolute/path/to/project \
      --mode inspect \
      --ephemeral
```

### Use a structured task specification

Prefer this form when another agent needs an explicit objective and acceptance
contract:

```bash
uv run cxa run \
  --cwd /absolute/path/to/project \
  --mode edit \
  --ephemeral \
  --timeout 900 \
  --objective "Fix the failing parser tests." \
  --constraint "Do not change the public parser API." \
  --acceptance "The focused parser tests pass." \
  --validation "Run the focused parser test target."
```

Repeat `--constraint`, `--acceptance`, or `--validation` to supply multiple
items.

### Stream events

```bash
uv run cxa run \
  --cwd /absolute/path/to/project \
  --mode inspect \
  --ephemeral \
  --stream \
  --prompt "Summarize the repository."
```

Streaming emits one JSON object per event. `--stream` and `--timeout` cannot be
used together.

## Persistent threads and resuming

Only create a persistent thread when continuity is an explicit requirement:

```bash
uv run cxa run \
  --cwd /absolute/path/to/project \
  --mode inspect \
  --persistent \
  --prompt "Begin a multi-turn investigation of the parser failures."
```

The JSON result includes `thread_id`. Save that ID, then resume it with:

```bash
uv run cxa run \
  --cwd /absolute/path/to/project \
  --thread THREAD_ID \
  --mode inspect \
  --prompt "Now compare the two likely root causes."
```

Do not add `--ephemeral` or `--persistent` when resuming; those flags apply only
when creating a new thread.

Persistent transcripts are stored by the Codex runtime under:

```text
${CODEX_HOME:-$HOME/.codex}/sessions
```

If future resumption is not required, use an ephemeral one-off run instead.

Ephemeral means “not saved as a resumable Codex thread.” It does not guarantee
that prompts are absent from caller logs, shell history, diagnostic logs, or
the service-side systems used to process the request. Do not put secrets in a
prompt merely because the run is ephemeral.

## Model selection

Omit `--model` to use the current Codex default. To request a specific model:

```bash
uv run cxa run \
  --cwd /absolute/path/to/project \
  --mode inspect \
  --model gpt-5.6-sol \
  --ephemeral \
  --prompt "Reply with exactly: OK"
```

List models exposed by the current runtime and account with:

```bash
uv run cxa rpc model/list --params '{}'
```

Do not hard-code a model unless the task requires that exact model. Model
availability depends on the installed runtime and the authenticated account.

## Instructions

The default, `--instructions native`, preserves normal Codex instruction
discovery, including global and project `AGENTS.md` files. Use it unless the
caller explicitly needs automation-specific behavior.

`--instructions headless` adds the package's non-interactive operating rules.
You may also pass the path to a developer-instructions file:

```bash
uv run cxa run \
  --cwd /absolute/path/to/project \
  --mode inspect \
  --instructions /absolute/path/to/instructions.md \
  --ephemeral \
  --prompt "Review the requested files."
```

## Structured JSON output

Pass a JSON Schema file when a machine must consume the answer:

```bash
uv run cxa run \
  --cwd /absolute/path/to/project \
  --mode inspect \
  --ephemeral \
  --schema /absolute/path/to/result.schema.json \
  --prompt "Return the repository health assessment."
```

The command prints a JSON `RunResult`. Important fields are:

- `thread_id`: the Codex thread identifier
- `turn_id`: the turn identifier
- `status`: normally `completed`, `failed`, or `interrupted`
- `final_response`: the final text response
- `output`: validated structured output when a schema was supplied
- `items`: collected turn items
- `usage`: token usage reported by the runtime
- `error`: failure details, if any

Check both the process exit code and the result's `status`. Do not infer success
from the presence of output alone.

For typed Python output, pass an ordinary Pydantic model with `output_model`.
The client converts it to the strict object schema required by Codex, including
nested models, and validates the final response before returning:

```python
from typing import Literal

from pydantic import BaseModel

from codex_app_client import Client


class Answer(BaseModel):
    answer: Literal[2]


with Client() as client:
    session = client.start(
        cwd="/absolute/path/to/project",
        sandbox="read-only",
        approvals="deny-all",
        instructions="headless",
        model="gpt-5.6-sol",
        ephemeral=True,
    )
    result = session.run(
        "Return JSON with answer equal to 1+1.",
        output_model=Answer,
        timeout_seconds=120,
    )
    assert result.output == Answer(answer=2)
```

## Health checks

Before relying on a new installation, run:

```bash
uv run cxa doctor --cwd /absolute/path/to/project
```

`doctor` starts an ephemeral, read-only thread and reports the selected model,
sandbox, approval policy, and discovered instruction sources. It does not run a
model turn.

For a minimal live smoke test:

```bash
uv run cxa run \
  --cwd /absolute/path/to/project \
  --mode inspect \
  --model gpt-5.6-sol \
  --ephemeral \
  --timeout 120 \
  --prompt "Reply with exactly: OK"
```

When validating persistent create/resume behavior, use an isolated temporary
`CODEX_HOME` so test threads do not pollute the user's normal session history.
The temporary home needs access to valid authentication and configuration, and
must be removed after the test. Never delete or rewrite the user's normal
`$CODEX_HOME` as part of a smoke test.

The package's opt-in integration suite performs a minimal live GPT-5.6 typed
output turn:

```bash
uv run pytest -m integration tests/integration
```

It requires Codex authentication and network access and spends model tokens, so
do not run it as part of every fast local check.

## Exit codes

| Code | Meaning |
|---:|---|
| `0` | Success |
| `2` | Invalid input or policy configuration |
| `3` | Authentication or configuration failure |
| `4` | Action denied |
| `5` | Turn failed |
| `6` | Timeout or interruption under timeout |
| `7` | Protocol or runtime failure |
| `8` | Structured-output validation failure |
| `9` | Unsupported server request |

On exit code `6`, the command may also print a partial `RunResult` containing an
interrupted status and any events collected before the deadline. Treat it as
diagnostic data, not as a successful answer.

## Raw RPC calls

Use `cxa rpc` only when the higher-level `run` or `doctor` commands do not cover
the task. Safe read-only methods are allowlisted. Always pass a JSON object for
parameters, including `{}` when a method has no meaningful parameters:

```bash
uv run cxa rpc account/read --params '{}'
uv run cxa rpc model/list --params '{}'
uv run cxa rpc thread/list --params '{}'
```

Non-allowlisted RPC calls require both `--unsafe` and
`CODEX_APP_CLIENT_UNSAFE=1`. Handshake methods remain forbidden. Do not use raw
unsafe RPC as a shortcut around the public client or its safety policies.

## Python API

Use the Python API when the caller needs typed results, repeated turns, or
programmatic event handling:

```python
from codex_app_client import Client, RunSpec

with Client() as client:
    session = client.start(
        cwd="/absolute/path/to/project",
        sandbox="read-only",
        approvals="deny-all",
        instructions="native",
        model="gpt-5.6-sol",
        ephemeral=True,
    )
    result = session.run(
        RunSpec(objective="Explain what this repository does."),
        timeout_seconds=120,
    )
    if result.status != "completed":
        raise RuntimeError(result.error or result.status)
    print(result.final_response)
```

The Python API also defaults new sessions to `ephemeral=True`. Keep it explicit
for one-off automation. Use `ephemeral=False` only when intentionally creating
a thread that will later be resumed.

## Operating checklist for agents

Before invoking the client:

1. Set `--cwd` to the exact target project.
2. Use `inspect` unless edits were explicitly requested.
3. Add `--ephemeral` for every one-off request.
4. Use a persistent thread only for deliberate multi-turn continuity.
5. State the objective, constraints, acceptance criteria, and validation when
   requesting changes.
6. Set a reasonable timeout for non-streaming automation.
7. Check the exit code and `status` before reporting success.
8. Preserve unrelated working-tree changes and never publish or deploy unless
   the user explicitly authorizes it.
