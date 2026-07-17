# Transport contract tests against the fake JSONL app-server.
# USAGE: uv run pytest tests/fake_server/test_transport_contract.py

from __future__ import annotations

import sys
from pathlib import Path

import pytest

from codex_app_client.client import Client
from codex_app_client.errors import TurnTimeoutError, UnsupportedServerRequest
from codex_app_client.models import ApprovalMode, Sandbox
from codex_app_client.policies import fail_closed_server_request

SERVER = Path(__file__).with_name("server.py")


def _launch_args() -> tuple[str, ...]:
    return (sys.executable, str(SERVER))


def _client(**kwargs: object) -> Client:
    return Client(
        launch_args_override=_launch_args(),
        server_request_handler=kwargs.pop("server_request_handler", fail_closed_server_request),  # type: ignore[arg-type]
        **kwargs,  # type: ignore[arg-type]
    )


def test_initialize_and_thread_start_instruction_sources() -> None:
    with _client() as client:
        session = client.start(
            cwd=".",
            sandbox=Sandbox.READ_ONLY,
            approvals=ApprovalMode.DENY_ALL,
            ephemeral=True,
        )
        assert session.thread_id.startswith("thread-")
        assert session.model == "fake-model"
        sources = [str(p) for p in session.instruction_sources]
        assert any(s.endswith("AGENTS.md") for s in sources)


def test_run_collects_final_response() -> None:
    with _client() as client:
        session = client.start(cwd=".", ephemeral=True)
        result = session.run("FINAL:hello-world")
        assert result.final_response == "hello-world"
        assert result.status == "completed"
        assert result.turn_id.startswith("turn-")
        assert result.usage is not None


def test_run_accepts_turn_reasoning_effort() -> None:
    with _client() as client:
        session = client.start(cwd=".", ephemeral=True)
        result = session.run("FINAL:effort-ok", effort="medium")
        assert result.final_response == "effort-ok"


def test_stream_emits_turn_completed() -> None:
    with _client() as client:
        session = client.start(cwd=".", ephemeral=True)
        methods = [event.method for event in session.stream("hello")]
        assert "item/completed" in methods
        assert methods[-1] == "turn/completed"


def test_default_handler_declines_command_approval() -> None:
    decisions: list[dict] = []

    def tracking_handler(method: str, params: dict | None) -> dict:
        result = fail_closed_server_request(method, params)
        decisions.append(result)
        return result

    with _client(server_request_handler=tracking_handler) as client:
        session = client.start(cwd=".", ephemeral=True)
        # Fake server may send approval request then complete the turn.
        # The approval handler is invoked on the reader thread; if it raises,
        # the turn stream fails.
        result = session.run("REQUEST_COMMAND_APPROVAL")
        assert result.status == "completed"
    assert decisions == [{"decision": "decline"}]


def test_unknown_server_request_fails_run() -> None:
    with _client() as client:
        session = client.start(cwd=".", ephemeral=True)
        with pytest.raises((UnsupportedServerRequest, Exception)):
            # Handler raises UnsupportedServerRequest on reader thread; SDK
            # surfaces that as a transport/router failure to the waiter.
            session.run("UNKNOWN_SERVER_REQUEST")


def test_safe_rpc_model_list() -> None:
    with _client() as client:
        result = client.rpc("model/list")
        assert "data" in result


def test_timeout_interrupt_raises_turn_timeout_error() -> None:
    with _client() as client:
        session = client.start(cwd=".", ephemeral=True)
        with pytest.raises(TurnTimeoutError) as exc:
            # Prompt completes quickly after interrupt as interrupted status.
            # Force a tiny timeout by racing a never-complete turn.
            session.run(
                "NEVER_COMPLETE",
                timeout_seconds=0.05,
                interrupt_grace_seconds=1.0,
            )
        assert exc.value.client_closed is False
        assert exc.value.partial is not None
        assert exc.value.partial.status == "interrupted"


def test_timeout_with_interrupt_leaves_client_open() -> None:
    with _client() as client:
        session = client.start(cwd=".", ephemeral=True)
        with pytest.raises(TurnTimeoutError) as exc:
            session.run(
                "NEVER_COMPLETE",
                timeout_seconds=0.05,
                interrupt_grace_seconds=1.0,
            )
        assert exc.value.client_closed is False
        assert client.closed is False
        session2 = client.start(cwd=".", ephemeral=True)
        result = session2.run("FINAL:after-timeout")
        assert result.final_response == "after-timeout"
