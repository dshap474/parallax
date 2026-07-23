# Unit tests for CLI exit-code mapping helpers.
# USAGE: uv run pytest tests/unit/test_cli_exit.py

from __future__ import annotations

from codex_app_client.cli import (
    EXIT_OK,
    EXIT_TIMEOUT,
    EXIT_TURN_FAILED,
    _exit_from_status,
    _exit_from_stream_events,
    build_parser,
)
from codex_app_client.models import Event


def test_new_threads_default_to_ephemeral() -> None:
    args = build_parser().parse_args(["run", "--prompt", "hello"])
    assert args.ephemeral is True


def test_persistent_new_thread_requires_explicit_flag() -> None:
    args = build_parser().parse_args(
        ["run", "--persistent", "--prompt", "hello"]
    )
    assert args.ephemeral is False


def test_ephemeral_flag_remains_supported() -> None:
    args = build_parser().parse_args(["run", "--ephemeral", "--prompt", "hello"])
    assert args.ephemeral is True


def test_run_accepts_explicit_model_and_effort() -> None:
    args = build_parser().parse_args(
        [
            "run",
            "--model",
            "gpt-5.6-terra",
            "--effort",
            "low",
            "--prompt",
            "hello",
        ]
    )
    assert args.model == "gpt-5.6-terra"
    assert args.effort == "low"


def test_exit_from_status() -> None:
    assert _exit_from_status("completed") == EXIT_OK
    assert _exit_from_status("interrupted") == EXIT_TIMEOUT
    assert _exit_from_status("failed") == EXIT_TURN_FAILED
    assert _exit_from_status("unknown") == EXIT_TURN_FAILED


def test_exit_from_stream_events_completed() -> None:
    events = [
        Event(
            method="turn/completed",
            thread_id="t1",
            turn_id="u1",
            payload={"turn": {"id": "u1", "status": "completed"}},
        )
    ]
    assert _exit_from_stream_events(events, thread_id="t1") == EXIT_OK


def test_exit_from_stream_events_failed() -> None:
    events = [
        Event(
            method="turn/completed",
            thread_id="t1",
            turn_id="u1",
            payload={
                "turn": {
                    "id": "u1",
                    "status": "failed",
                    "error": {"message": "nope"},
                }
            },
        )
    ]
    assert _exit_from_stream_events(events, thread_id="t1") == EXIT_TURN_FAILED


def test_exit_from_stream_events_interrupted() -> None:
    events = [
        Event(
            method="turn/completed",
            thread_id="t1",
            turn_id="u1",
            payload={"turn": {"id": "u1", "status": "interrupted"}},
        )
    ]
    assert _exit_from_stream_events(events, thread_id="t1") == EXIT_TIMEOUT
