# Unit tests for event normalization and final-response selection.
# USAGE: uv run pytest tests/unit/test_result_collection.py

from __future__ import annotations

import inspect
from types import SimpleNamespace

import pytest
from pydantic import BaseModel, ValidationError

from codex_app_client.client import (
    Client,
    StartOptions,
    _coerce_output_schema,
    build_thread_params,
    collect_from_events,
    normalize_event,
)
from codex_app_client.errors import OutputValidationError, TurnFailedError
from codex_app_client.models import ApprovalMode, Event, InstructionMode, RunResult, Sandbox


def test_normalize_event_extracts_ids() -> None:
    notification = SimpleNamespace(
        method="item/completed",
        payload=SimpleNamespace(
            model_dump=lambda **_k: {
                "threadId": "t1",
                "turnId": "u1",
                "item": {"type": "agentMessage", "text": "hi", "phase": "final_answer"},
            }
        ),
    )
    event = normalize_event(notification)
    assert event.method == "item/completed"
    assert event.thread_id == "t1"
    assert event.turn_id == "u1"
    assert event.payload["item"]["text"] == "hi"


def test_collect_prefers_final_answer_phase() -> None:
    events = [
        Event(
            method="item/completed",
            thread_id="t1",
            turn_id="u1",
            payload={
                "item": {
                    "type": "agentMessage",
                    "text": "draft",
                    "phase": None,
                }
            },
        ),
        Event(
            method="item/completed",
            thread_id="t1",
            turn_id="u1",
            payload={
                "item": {
                    "type": "agentMessage",
                    "text": '{"ok": true}',
                    "phase": "final_answer",
                }
            },
        ),
        Event(
            method="turn/completed",
            thread_id="t1",
            turn_id="u1",
            payload={
                "threadId": "t1",
                "turn": {
                    "id": "u1",
                    "status": "completed",
                    "startedAt": 1,
                    "completedAt": 2,
                    "durationMs": 1,
                    "error": None,
                },
            },
        ),
    ]
    result = collect_from_events(iter(events), thread_id="t1", turn_id="u1")
    assert isinstance(result, RunResult)
    assert result.final_response == '{"ok": true}'
    assert result.status == "completed"
    assert result.duration_ms == 1


def test_collect_raises_on_failed_turn() -> None:
    events = [
        Event(
            method="turn/completed",
            thread_id="t1",
            turn_id="u1",
            payload={
                "turn": {
                    "id": "u1",
                    "status": "failed",
                    "error": {"message": "boom"},
                }
            },
        )
    ]
    with pytest.raises(TurnFailedError, match="boom") as exc:
        collect_from_events(iter(events), thread_id="t1", turn_id="u1")
    assert exc.value.status == "failed"
    assert exc.value.result is not None


def test_collect_raises_on_interrupted_turn() -> None:
    events = [
        Event(
            method="turn/completed",
            thread_id="t1",
            turn_id="u1",
            payload={
                "turn": {
                    "id": "u1",
                    "status": "interrupted",
                    "error": None,
                }
            },
        )
    ]
    with pytest.raises(TurnFailedError, match="interrupted") as exc:
        collect_from_events(iter(events), thread_id="t1", turn_id="u1")
    assert exc.value.status == "interrupted"


def test_collect_partial_allows_interrupted() -> None:
    events = [
        Event(
            method="turn/completed",
            thread_id="t1",
            turn_id="u1",
            payload={"turn": {"id": "u1", "status": "interrupted"}},
        )
    ]
    result = collect_from_events(
        iter(events),
        thread_id="t1",
        turn_id="u1",
        require_completed=False,
    )
    assert result.status == "interrupted"


def test_build_thread_params_headless_and_policies() -> None:
    options = StartOptions(
        cwd=".",
        sandbox=Sandbox.WORKSPACE_WRITE,
        approvals=ApprovalMode.AUTO_REVIEW,
        instructions=InstructionMode.HEADLESS,
        model="gpt-test",
        ephemeral=True,
    )
    params = build_thread_params(options)
    assert params["sandbox"] == "workspace-write"
    assert params["approvalPolicy"] == "on-request"
    assert params["approvalsReviewer"] == "auto_review"
    assert params["ephemeral"] is True
    assert params["model"] == "gpt-test"
    assert "non-interactive automation run" in params["developerInstructions"]
    assert "baseInstructions" not in params
    assert "base_instructions" not in params


def test_python_client_new_threads_default_to_ephemeral() -> None:
    parameter = inspect.signature(Client.start).parameters["ephemeral"]
    assert parameter.default is True


def test_output_model_schema_closes_nested_objects() -> None:
    class Detail(BaseModel):
        value: int

    class Report(BaseModel):
        detail: Detail

    schema = _coerce_output_schema(Report)

    assert schema is not None
    assert schema["additionalProperties"] is False
    assert schema["$defs"]["Detail"]["additionalProperties"] is False


def test_build_thread_params_sparse_resume_omits_unset() -> None:
    params = build_thread_params(StartOptions(model="only-model"))
    assert params == {"model": "only-model"}


def test_build_thread_params_accepts_explicit_base_instructions() -> None:
    params = build_thread_params(
        StartOptions(instructions="worker rules", base_instructions="minimal base")
    )
    assert params["developerInstructions"] == "worker rules"
    assert params["baseInstructions"] == "minimal base"


def test_build_thread_params_blocks_full_access(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.delenv("CODEX_APP_CLIENT_UNSAFE", raising=False)
    options = StartOptions(
        sandbox=Sandbox.FULL_ACCESS,
        unsafe=True,
    )
    with pytest.raises(Exception, match="full-access"):
        build_thread_params(options)


def test_output_model_validation_path() -> None:
    class Report(BaseModel):
        status: str
        summary: str

    # Simulate run() validation logic
    final = '{"status": "completed", "summary": "ok"}'
    parsed = Report.model_validate_json(final)
    assert parsed.status == "completed"

    with pytest.raises(ValidationError):
        Report.model_validate_json('{"status": 1}')


def test_output_validation_error_keeps_final_response() -> None:
    err = OutputValidationError("bad", final_response='{"x": 1}')
    assert err.final_response == '{"x": 1}'
