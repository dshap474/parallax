# Unit tests for RunSpec rendering and resource loading.
# USAGE: uv run pytest tests/unit/test_prompts.py

from __future__ import annotations

from pathlib import Path

import pytest

from codex_app_client.models import RunSpec
from codex_app_client.prompts import load_agents_template, load_headless_instructions


def test_run_spec_render_includes_core_sections() -> None:
    text = RunSpec(
        objective="Fix the failing parser tests.",
        constraints=[
            "Do not change the public parser API.",
            "Preserve unrelated working-tree changes.",
        ],
        acceptance_criteria=[
            "The parser test target passes.",
            "New behavior is covered by a regression test.",
        ],
        validation=[
            "Run the focused parser test target.",
            "Run the relevant static checks.",
        ],
    ).render(include_output_schema_instruction=True)

    assert "## Objective" in text
    assert "Fix the failing parser tests." in text
    assert "## Constraints" in text
    assert "Do not change the public parser API." in text
    assert "## Acceptance criteria" in text
    assert "## Validation" in text
    assert "## Final response" in text
    assert "supplied output schema" in text


def test_run_spec_omits_schema_instruction_by_default() -> None:
    text = RunSpec(objective="Only objective").render()
    assert "## Final response" not in text
    assert "output schema" not in text


def test_run_spec_omits_empty_optional_sections() -> None:
    text = RunSpec(objective="Only objective").render()
    assert "## Context" not in text
    assert "## Constraints" not in text
    assert "## Acceptance criteria" not in text
    assert "## Validation" not in text


def test_headless_instructions_loaded() -> None:
    text = load_headless_instructions()
    assert "non-interactive automation run" in text
    assert "Do not ask conversational follow-up questions" in text


def test_agents_template_loaded() -> None:
    text = load_agents_template()
    assert "# Repository instructions" in text
    assert "## Definition of done" in text


def test_init_refuses_overwrite(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    from codex_app_client.cli import cmd_init

    agents = tmp_path / "AGENTS.md"
    agents.write_text("existing\n", encoding="utf-8")

    class Args:
        stdout = False
        force = False
        cwd = tmp_path

    assert cmd_init(Args()) == 2
    assert agents.read_text(encoding="utf-8") == "existing\n"
