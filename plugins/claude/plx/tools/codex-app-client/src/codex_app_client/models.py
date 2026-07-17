# Public domain models for codex-app-client.
# USAGE:
#   from codex_app_client.models import RunSpec, RunResult, Event, Sandbox
#   prompt = RunSpec(objective="Fix tests").render()

from __future__ import annotations

from enum import StrEnum
from pathlib import Path
from typing import Any

from pydantic import BaseModel, Field

# --------------------------------------------------------------------------- #
# Enums
# --------------------------------------------------------------------------- #


class Sandbox(StrEnum):
    READ_ONLY = "read-only"
    WORKSPACE_WRITE = "workspace-write"
    FULL_ACCESS = "full-access"


class ApprovalMode(StrEnum):
    DENY_ALL = "deny-all"
    AUTO_REVIEW = "auto-review"


class InstructionMode(StrEnum):
    NATIVE = "native"
    HEADLESS = "headless"


class CliMode(StrEnum):
    INSPECT = "inspect"
    EDIT = "edit"
    CI_EDIT = "ci-edit"


# --------------------------------------------------------------------------- #
# Task and session models
# --------------------------------------------------------------------------- #


class RunSpec(BaseModel):
    """Structured task description rendered into a turn prompt."""

    objective: str
    context: list[str] = Field(default_factory=list)
    constraints: list[str] = Field(default_factory=list)
    acceptance_criteria: list[str] = Field(default_factory=list)
    validation: list[str] = Field(default_factory=list)

    def render(self, *, include_output_schema_instruction: bool = False) -> str:
        """Render a simple multi-section task prompt.

        When ``include_output_schema_instruction`` is true, append a final-response
        note about the supplied output schema. Only enable that when a schema or
        output model is actually provided for the turn.
        """
        sections: list[str] = [f"## Objective\n\n{self.objective.strip()}"]

        if self.context:
            sections.append("## Context\n\n" + _bullet_list(self.context))
        if self.constraints:
            sections.append("## Constraints\n\n" + _bullet_list(self.constraints))
        if self.acceptance_criteria:
            sections.append(
                "## Acceptance criteria\n\n" + _bullet_list(self.acceptance_criteria)
            )
        if self.validation:
            sections.append("## Validation\n\n" + _bullet_list(self.validation))

        if include_output_schema_instruction:
            sections.append(
                "## Final response\n\n"
                "Return the result using the supplied output schema."
            )
        return "\n\n".join(sections)


class SessionInfo(BaseModel):
    """Metadata returned when a thread is started, resumed, or forked."""

    thread_id: str
    cwd: Path
    model: str
    model_provider: str | None = None
    instruction_sources: list[Path] = Field(default_factory=list)
    sandbox: dict[str, Any] | None = None
    approval_policy: Any = None
    approvals_reviewer: str | None = None


class Event(BaseModel):
    """Normalized app-server notification retained for streaming callers."""

    method: str
    thread_id: str | None = None
    turn_id: str | None = None
    payload: dict[str, Any]


class RunResult(BaseModel):
    """Collected result of one completed (or failed) turn."""

    thread_id: str
    turn_id: str
    status: str
    final_response: str | None
    output: Any = None
    items: list[dict[str, Any]] = Field(default_factory=list)
    usage: dict[str, Any] | None = None
    error: dict[str, Any] | None = None
    started_at: int | None = None
    completed_at: int | None = None
    duration_ms: int | None = None


# --------------------------------------------------------------------------- #
# Helpers
# --------------------------------------------------------------------------- #


def _bullet_list(items: list[str]) -> str:
    return "\n".join(f"- {item.strip()}" for item in items if item.strip())
