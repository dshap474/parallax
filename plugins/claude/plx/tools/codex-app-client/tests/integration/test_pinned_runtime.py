# Live contract tests against the pinned openai-codex runtime.
# USAGE:
#   uv run pytest -m integration tests/integration
#
# Requires Codex authentication and network access on the host. Runs one
# minimal live model turn. Skipped by default via addopts.

from __future__ import annotations

from pathlib import Path
from typing import Literal

import pytest
from pydantic import BaseModel

from codex_app_client.client import Client
from codex_app_client.models import ApprovalMode, InstructionMode, Sandbox

pytestmark = pytest.mark.integration


def test_real_runtime_doctor_thread(tmp_path: Path) -> None:
    (tmp_path / "AGENTS.md").write_text("# Project\n\n- Use focused tests.\n", encoding="utf-8")
    service = tmp_path / "service"
    service.mkdir()
    (service / "AGENTS.override.md").write_text(
        "# Service override\n\n- Prefer service tests.\n",
        encoding="utf-8",
    )

    with Client() as client:
        session = client.start(
            cwd=service,
            sandbox=Sandbox.READ_ONLY,
            approvals=ApprovalMode.DENY_ALL,
            instructions=InstructionMode.NATIVE,
            ephemeral=True,
        )
        assert session.thread_id
        assert session.model
        sources = [str(p) for p in session.instruction_sources]
        # Real runtime should discover nested instruction files when present.
        assert sources, "expected instruction_sources from app-server"


def test_real_runtime_gpt_5_6_turn(tmp_path: Path) -> None:
    """Prove GPT-5.6 accepts the client's generated strict output schema."""

    class Answer(BaseModel):
        answer: Literal[2]

    with Client() as client:
        session = client.start(
            cwd=tmp_path,
            sandbox=Sandbox.READ_ONLY,
            approvals=ApprovalMode.DENY_ALL,
            instructions=InstructionMode.HEADLESS,
            model="gpt-5.6-sol",
        )
        result = session.run(
            "Return JSON with answer equal to 1+1.",
            output_model=Answer,
            timeout_seconds=120,
        )

    assert session.model == "gpt-5.6-sol"
    assert result.status == "completed"
    assert result.output == Answer(answer=2)
    assert result.usage is not None
