# Minimal JSONL app-server stand-in for transport contract tests.
# USAGE:
#   CodexConfig(launch_args_override=(sys.executable, path/to/server.py))
#
# Speaks enough of the initialize + thread/turn protocol for unit-style
# end-to-end tests without the real Codex binary.

from __future__ import annotations

import json
import sys
import threading
import time
from typing import Any

# --------------------------------------------------------------------------- #
# State
# --------------------------------------------------------------------------- #

_turn_counter = 0
_thread_counter = 0
_lock = threading.Lock()


def _next_turn_id() -> str:
    global _turn_counter
    with _lock:
        _turn_counter += 1
        return f"turn-{_turn_counter}"


def _next_thread_id() -> str:
    global _thread_counter
    with _lock:
        _thread_counter += 1
        return f"thread-{_thread_counter}"


def _write(msg: dict[str, Any]) -> None:
    sys.stdout.write(json.dumps(msg) + "\n")
    sys.stdout.flush()


def _notify(method: str, params: dict[str, Any]) -> None:
    _write({"method": method, "params": params})


def _respond(req_id: Any, result: dict[str, Any]) -> None:
    _write({"id": req_id, "result": result})


def _error(req_id: Any, code: int, message: str) -> None:
    _write({"id": req_id, "error": {"code": code, "message": message}})


def _token_usage() -> dict[str, Any]:
    breakdown = {
        "inputTokens": 1,
        "cachedInputTokens": 0,
        "outputTokens": 1,
        "reasoningOutputTokens": 0,
        "totalTokens": 2,
    }
    return {"last": breakdown, "total": breakdown, "modelContextWindow": 128000}


# --------------------------------------------------------------------------- #
# Handlers
# --------------------------------------------------------------------------- #


def handle_initialize(req_id: Any, _params: dict[str, Any] | None) -> None:
    _respond(
        req_id,
        {
            "userAgent": "fake-app-server/0.0.0",
            "platformFamily": "unix",
            "platformOs": "macos",
        },
    )


def handle_thread_start(req_id: Any, params: dict[str, Any] | None) -> None:
    params = params or {}
    thread_id = _next_thread_id()
    cwd = params.get("cwd") or "/tmp"
    if not str(cwd).startswith("/"):
        cwd = "/tmp"
    result = {
        "thread": {
            "id": thread_id,
            "sessionId": thread_id,
            "preview": "",
            "modelProvider": "fake",
            "createdAt": 0,
            "updatedAt": 0,
            "status": {"type": "idle"},
            "path": None,
            "cliVersion": "0.0.0",
            "source": "cli",
            "cwd": cwd,
            "ephemeral": bool(params.get("ephemeral", False)),
            "turns": [],
            "name": None,
        },
        "model": params.get("model") or "fake-model",
        "modelProvider": "fake",
        "cwd": cwd,
        "approvalPolicy": params.get("approvalPolicy") or "never",
        "approvalsReviewer": params.get("approvalsReviewer") or "user",
        "sandbox": {"type": "readOnly"},
        "instructionSources": [
            "/home/user/.codex/AGENTS.md",
            f"{cwd.rstrip('/')}/AGENTS.md",
        ],
        "reasoningEffort": None,
        "serviceTier": None,
    }
    _respond(req_id, result)


def handle_turn_start(req_id: Any, params: dict[str, Any] | None) -> None:
    params = params or {}
    thread_id = params.get("threadId") or "thread-1"
    turn_id = _next_turn_id()
    input_items = params.get("input") or []
    text = ""
    if input_items and isinstance(input_items[0], dict):
        text = str(input_items[0].get("text") or "")

    turn = {
        "id": turn_id,
        "items": [],
        "itemsView": "full",
        "status": "inProgress",
        "error": None,
        "startedAt": int(time.time() * 1000),
        "completedAt": None,
        "durationMs": None,
    }
    _respond(req_id, {"turn": turn})

    # Give the client time to register the turn notification queue after
    # turn/start returns; otherwise early notifications can be dropped.
    time.sleep(0.05)

    if text.startswith("REQUEST_COMMAND_APPROVAL"):
        _write(
            {
                "id": f"srv-cmd-{turn_id}",
                "method": "item/commandExecution/requestApproval",
                "params": {
                    "command": "echo hi",
                    "threadId": thread_id,
                    "turnId": turn_id,
                },
            }
        )
    if text.startswith("REQUEST_FILE_APPROVAL"):
        _write(
            {
                "id": f"srv-file-{turn_id}",
                "method": "item/fileChange/requestApproval",
                "params": {
                    "paths": ["a.py"],
                    "threadId": thread_id,
                    "turnId": turn_id,
                },
            }
        )
    if text.startswith("UNKNOWN_SERVER_REQUEST"):
        _write(
            {
                "id": f"srv-unknown-{turn_id}",
                "method": "item/tool/requestUserInput",
                "params": {
                    "prompt": "what?",
                    "threadId": thread_id,
                    "turnId": turn_id,
                },
            }
        )

    if text.startswith("NEVER_COMPLETE"):
        _notify("turn/started", {"threadId": thread_id, "turn": turn})
        return

    final_text = '{"status":"completed","summary":"ok"}'
    if text.startswith("FINAL:"):
        final_text = text[len("FINAL:") :]

    agent_item = {
        "type": "agentMessage",
        "id": f"item-{turn_id}",
        "text": final_text,
        "phase": "final_answer",
    }
    _notify(
        "item/completed",
        {
            "threadId": thread_id,
            "turnId": turn_id,
            "item": agent_item,
            "completedAtMs": int(time.time() * 1000),
        },
    )
    _notify(
        "thread/tokenUsage/updated",
        {
            "threadId": thread_id,
            "turnId": turn_id,
            "tokenUsage": _token_usage(),
        },
    )
    completed = {
        **turn,
        "status": "completed",
        "completedAt": int(time.time() * 1000),
        "durationMs": 5,
        "items": [agent_item],
    }
    _notify("turn/completed", {"threadId": thread_id, "turn": completed})


def handle_turn_interrupt(req_id: Any, params: dict[str, Any] | None) -> None:
    params = params or {}
    turn_id = params.get("turnId") or "turn-1"
    thread_id = params.get("threadId") or "thread-1"
    _respond(req_id, {})
    _notify(
        "turn/completed",
        {
            "threadId": thread_id,
            "turn": {
                "id": turn_id,
                "items": [],
                "itemsView": "full",
                "status": "interrupted",
                "error": None,
                "startedAt": 0,
                "completedAt": int(time.time() * 1000),
                "durationMs": 1,
            },
        },
    )


def handle_model_list(req_id: Any, _params: dict[str, Any] | None) -> None:
    # Returned through ObjectResponse (dict), so shape can be simple.
    _respond(
        req_id,
        {
            "data": [
                {
                    "id": "fake-model",
                    "model": "fake-model",
                    "displayName": "Fake",
                    "description": "fake",
                    "hidden": False,
                    "isDefault": True,
                    "defaultReasoningEffort": "low",
                    "supportedReasoningEfforts": [],
                }
            ],
            "nextCursor": None,
        },
    )


HANDLERS = {
    "initialize": handle_initialize,
    "thread/start": handle_thread_start,
    "turn/start": handle_turn_start,
    "turn/interrupt": handle_turn_interrupt,
    "model/list": handle_model_list,
}


# --------------------------------------------------------------------------- #
# Main loop
# --------------------------------------------------------------------------- #


def main() -> None:
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            continue

        # Client responses to our server requests
        if "id" in msg and "method" not in msg and ("result" in msg or "error" in msg):
            continue

        # Notifications from client (initialized)
        if "method" in msg and "id" not in msg:
            continue

        method = msg.get("method")
        req_id = msg.get("id")
        params = msg.get("params")
        if not isinstance(method, str):
            continue

        if (
            method == "thread/start"
            and isinstance(params, dict)
            and params.get("model") == "OVERLOAD"
        ):
            _error(req_id, -32001, "Server overloaded; retry later.")
            continue

        handler = HANDLERS.get(method)
        if handler is None:
            _error(req_id, -32601, f"Method not found: {method}")
            continue
        handler(req_id, params if isinstance(params, dict) else None)


if __name__ == "__main__":
    main()
