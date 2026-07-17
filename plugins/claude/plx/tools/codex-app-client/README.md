# codex-app-client

Thin, fail-closed Python client and machine-oriented CLI for Codex **app-server**.

This package wraps the official low-level `openai-codex` SDK (`CodexClient`), pins it to a matching bundled runtime, and exposes a small API:

```text
Client → Session → RunResult
```

plus the `cxa` CLI for agents and non-Python callers.

## Install (from monorepo)

```bash
cd tools/codex-app-client
uv sync --all-extras
```

Optional tool install:

```bash
uv tool install -e tools/codex-app-client
```

## Python API

```python
from codex_app_client import Client, RunSpec
from pydantic import BaseModel
from typing import Literal

class RunReport(BaseModel):
    status: Literal["completed", "blocked", "failed"]
    summary: str

with Client() as client:
    session = client.start(
        cwd=".",
        sandbox="workspace-write",
        approvals="auto-review",
        instructions="headless",
        ephemeral=True,
    )
    result = session.run(
        RunSpec(
            objective="Fix the failing parser tests.",
            constraints=["Do not change the public parser API."],
            acceptance_criteria=["The parser test target passes."],
            validation=["Run the focused parser test target."],
        ),
        output_model=RunReport,
        timeout_seconds=900,
    )
    print(result.output)
```

## CLI

```bash
cxa doctor
cxa init
cxa init --stdout
echo "Summarize AGENTS.md" | cxa run --mode inspect --stream
cxa rpc model/list --params '{}'
```

`cxa bridge --workers 4` starts one App Server and accepts correlated NDJSON structured-turn
requests on stdin. It is intended for long-lived local orchestrators: requests may finish out of
order, every request receives a fresh ephemeral read-only thread, and a `shutdown` request closes
the shared process. Ordinary one-off callers should continue to use `cxa run`.

New threads are ephemeral by default. Pass `--persistent` only when you
intentionally need a resumable thread. `--ephemeral` remains available when an
explicit marker is useful in automation.

### Modes

| Mode | Sandbox | Approvals |
|------|---------|-----------|
| `inspect` | read-only | deny-all |
| `edit` | workspace-write | auto-review |
| `ci-edit` | workspace-write | deny-all |

Full access is not a normal mode. It requires `--sandbox full-access --unsafe` and `CODEX_APP_CLIENT_UNSAFE=1`.

### Exit codes

| Code | Meaning |
|------|---------|
| 0 | success |
| 2 | invalid CLI input / policy configuration |
| 3 | auth/config failure |
| 4 | action denied |
| 5 | turn failed |
| 6 | timeout / interrupted under timeout |
| 7 | protocol/runtime failure |
| 8 | structured-output validation failure |
| 9 | unsupported server request |

## Safety defaults

- Always installs a fail-closed server-request handler (declines command and file-change approvals).
- Starts new threads as ephemeral unless persistence is explicitly requested.
- Disables experimental app-server APIs unless `experimental=True` / `--experimental`.
- Raw `rpc()` allowlists read-only methods; everything else needs `unsafe=True` **and** `CODEX_APP_CLIENT_UNSAFE=1`.
- Handshake methods `initialize` / `initialized` are never exposed.

## Tests

```bash
uv run pytest
uv run pytest -m integration   # needs auth/network; runs one minimal live turn
```

## Pinned runtime

- `openai-codex` pinned to official Codex commit
  `0f44bca9154e056a32fde7a89026b4620599e6f2`
- Bundled `openai-codex-cli-bin==0.144.4` (via the SDK dependency)

Do not float the SDK and binary independently.
