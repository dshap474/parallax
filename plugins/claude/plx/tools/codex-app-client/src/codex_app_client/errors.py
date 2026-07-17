# Public and internal error types for codex-app-client.
# USAGE:
#   raise UnsafeRpcError("thread/shellCommand requires unsafe mode")
#   raise OutputValidationError("structured output failed schema validation")

from __future__ import annotations

from typing import TYPE_CHECKING, Any

if TYPE_CHECKING:
    from codex_app_client.models import RunResult

# --------------------------------------------------------------------------- #
# Errors
# --------------------------------------------------------------------------- #


class CodexAppClientError(Exception):
    """Base error for this package."""


class UnsafeRpcError(CodexAppClientError):
    """Raised when a raw RPC method is blocked by the dual safety gate."""


class UnsupportedServerRequest(CodexAppClientError):
    """Raised when app-server asks for a server request we do not support."""

    def __init__(self, method: str) -> None:
        super().__init__(f"Unsupported app-server request: {method}")
        self.method = method


class ActiveTurnError(CodexAppClientError):
    """Raised when a second turn is started on a thread that is already busy."""


class ClientClosedError(CodexAppClientError):
    """Raised when an operation is attempted on a closed Client."""


class TurnTimeoutError(CodexAppClientError):
    """Raised when a turn exceeds the caller timeout.

    If interrupt completed with a terminal event, ``partial`` may hold a
    non-completed ``RunResult`` for inspection. A hard timeout that closes the
    Client is always fatal to that Client process.
    """

    def __init__(
        self,
        message: str,
        *,
        partial: RunResult | None = None,
        client_closed: bool = False,
    ) -> None:
        super().__init__(message)
        self.partial = partial
        self.client_closed = client_closed


class OutputValidationError(CodexAppClientError):
    """Raised when the final response does not match the requested output model."""

    def __init__(self, message: str, *, final_response: str | None = None) -> None:
        super().__init__(message)
        self.final_response = final_response


class TurnFailedError(CodexAppClientError):
    """Raised when a turn ends with a non-completed terminal status."""

    def __init__(
        self,
        message: str,
        *,
        error: dict[str, Any] | None = None,
        status: str | None = None,
        result: RunResult | None = None,
    ) -> None:
        super().__init__(message)
        self.error = error
        self.status = status
        self.result = result


class ConfigurationError(CodexAppClientError):
    """Raised for invalid client, CLI, or policy configuration."""
