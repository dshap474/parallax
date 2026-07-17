# Persistent NDJSON bridge from non-Python callers to one Codex app-server.
# USAGE:
#   printf '%s\n' '{"v":1,"id":"x","op":"shutdown"}' | cxa bridge

from __future__ import annotations

import json
import os
import sys
import tempfile
import threading
import time
from concurrent.futures import Future, ThreadPoolExecutor, wait
from pathlib import Path
from typing import Any

from codex_app_client.client import Client, Session
from codex_app_client.errors import ClientClosedError, TurnTimeoutError
from codex_app_client.models import ApprovalMode, Sandbox

# --------------------------------------------------------------------------- #
# Protocol
# --------------------------------------------------------------------------- #

PROTOCOL_VERSION = 1
BASE_INSTRUCTIONS = (
    "You are a structured transformation worker. Follow the user prompt exactly. "
    "Return only the JSON object required by the supplied output schema."
)


def _emit(payload: dict[str, Any], lock: threading.Lock) -> None:
    with lock:
        sys.stdout.write(json.dumps(payload, separators=(",", ":"), default=str) + "\n")
        sys.stdout.flush()


def _require(request: dict[str, Any], key: str, expected: type) -> Any:
    value = request.get(key)
    if not isinstance(value, expected):
        raise ValueError(f"{key} must be {expected.__name__}")
    return value


def _complete(
    client: Client,
    cwd: Path,
    request: dict[str, Any],
    active: dict[str, Session],
    active_lock: threading.Lock,
) -> dict[str, Any]:
    request_id = _require(request, "id", str)
    prompt = _require(request, "prompt", str)
    schema = _require(request, "schema", dict)
    model = _require(request, "model", str)
    reasoning = _require(request, "reasoning", str)
    timeout_ms = _require(request, "timeoutMs", int)
    started = time.monotonic()
    session = client.start(
        cwd=cwd,
        sandbox=Sandbox.READ_ONLY,
        approvals=ApprovalMode.DENY_ALL,
        instructions="",
        base_instructions=BASE_INSTRUCTIONS,
        model=model,
        ephemeral=True,
    )
    if session.instruction_sources:
        raise RuntimeError(
            "unexpected instruction sources: "
            + ", ".join(str(path) for path in session.instruction_sources)
        )
    with active_lock:
        active[request_id] = session
    try:
        result = session.run(
            prompt,
            output_schema=schema,
            timeout_seconds=timeout_ms / 1000,
            effort=reasoning,
        )
        if result.final_response is None:
            raise RuntimeError("turn completed without a final response")
        try:
            output = json.loads(result.final_response)
        except json.JSONDecodeError as exc:
            raise ValueError("turn produced malformed JSON") from exc
        return {
            "v": PROTOCOL_VERSION,
            "id": request_id,
            "ok": True,
            "output": output,
            "threadId": result.thread_id,
            "turnId": result.turn_id,
            "durationMs": result.duration_ms,
            "roundTripMs": round((time.monotonic() - started) * 1000),
            "usage": result.usage,
        }
    finally:
        with active_lock:
            active.pop(request_id, None)


def _error_response(request_id: str, exc: BaseException) -> dict[str, Any]:
    if isinstance(exc, TurnTimeoutError):
        code = "timeout"
    elif isinstance(exc, ClientClosedError):
        code = "bridge_failed"
    else:
        code = "request_failed"
    return {
        "v": PROTOCOL_VERSION,
        "id": request_id,
        "ok": False,
        "error": {"code": code, "message": str(exc)},
    }


def _complete_response(
    client: Client,
    cwd: Path,
    request: dict[str, Any],
    active: dict[str, Session],
    active_lock: threading.Lock,
) -> dict[str, Any]:
    request_id = str(request.get("id", "unknown"))
    try:
        return _complete(client, cwd, request, active, active_lock)
    except BaseException as exc:  # noqa: BLE001 - protocol boundary
        return _error_response(request_id, exc)


# --------------------------------------------------------------------------- #
# Bridge lifecycle
# --------------------------------------------------------------------------- #


def _prepare_codex_home(root: Path) -> Path:
    """Create a minimal home with auth but without ambient instructions or config."""
    codex_home = root / "codex-home"
    codex_home.mkdir()
    source_home = Path(os.environ.get("CODEX_HOME", Path.home() / ".codex"))
    auth = source_home / "auth.json"
    if not auth.is_file():
        raise RuntimeError(f"Codex authentication file not found: {auth}")
    (codex_home / "auth.json").symlink_to(auth)
    installation_id = source_home / "installation_id"
    if installation_id.is_file():
        (codex_home / "installation_id").symlink_to(installation_id)
    return codex_home


def run_bridge(*, workers: int) -> int:
    """Serve correlated NDJSON requests until stdin closes or shutdown arrives."""
    output_lock = threading.Lock()
    active_lock = threading.Lock()
    jobs_lock = threading.Lock()
    active: dict[str, Session] = {}
    futures: set[Future[dict[str, Any]]] = set()
    jobs: dict[str, Future[dict[str, Any]]] = {}
    graceful_shutdown = False

    with tempfile.TemporaryDirectory(prefix="cxa-bridge-") as directory:
        root = Path(directory)
        codex_home = _prepare_codex_home(root)
        workspace = root / "workspace"
        workspace.mkdir()
        with Client(
            env={"CODEX_HOME": str(codex_home)},
            config_overrides={"project_doc_max_bytes": 0},
        ) as client:
            with ThreadPoolExecutor(max_workers=workers, thread_name_prefix="cxa-bridge") as pool:
                _emit({"v": PROTOCOL_VERSION, "event": "ready"}, output_lock)

                def done(request_id: str, future: Future[dict[str, Any]]) -> None:
                    with jobs_lock:
                        futures.discard(future)
                        jobs.pop(request_id, None)
                    if future.cancelled():
                        return
                    try:
                        _emit(future.result(), output_lock)
                    except BaseException as exc:  # noqa: BLE001 - protocol boundary
                        _emit(_error_response("unknown", exc), output_lock)

                for line in sys.stdin:
                    request: Any = None
                    try:
                        request = json.loads(line)
                        if not isinstance(request, dict):
                            raise ValueError("request must be a JSON object")
                        if request.get("v") != PROTOCOL_VERSION:
                            raise ValueError("unsupported protocol version")
                        request_id = _require(request, "id", str)
                        operation = _require(request, "op", str)
                        if operation == "shutdown":
                            graceful_shutdown = True
                            break
                        if operation == "cancel":
                            with jobs_lock:
                                future = jobs.get(request_id)
                            future_cancelled = future.cancel() if future is not None else False
                            with active_lock:
                                session = active.get(request_id)
                            if session is not None and not future_cancelled:
                                session.interrupt()
                            continue
                        if operation != "complete":
                            raise ValueError(f"unsupported operation: {operation}")
                        future = pool.submit(
                            _complete_response,
                            client,
                            workspace,
                            request,
                            active,
                            active_lock,
                        )
                        with jobs_lock:
                            futures.add(future)
                            jobs[request_id] = future
                        future.add_done_callback(
                            lambda completed, request_id=request_id: done(
                                request_id, completed
                            )
                        )
                    except BaseException as exc:  # noqa: BLE001 - protocol boundary
                        request_id = (
                            request.get("id", "unknown")
                            if isinstance(request, dict)
                            else "unknown"
                        )
                        _emit(_error_response(str(request_id), exc), output_lock)

                with jobs_lock:
                    remaining = list(futures)
                if graceful_shutdown:
                    wait(remaining)
                else:
                    with active_lock:
                        sessions = list(active.values())
                    for session in sessions:
                        session.interrupt()
                    for future in remaining:
                        future.cancel()
                    wait(remaining)
    return 0
