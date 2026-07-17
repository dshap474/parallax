# codex-app-client: thin fail-closed client for Codex app-server.
# USAGE:
#   from codex_app_client import Client, RunSpec, RunResult
#   with Client() as client:
#       session = client.start(cwd=".", instructions="headless", ephemeral=True)
#       result = session.run(RunSpec(objective="Fix tests"))

from codex_app_client._version import __version__
from codex_app_client.client import Client, Session, StartOptions, build_thread_params
from codex_app_client.errors import (
    ActiveTurnError,
    ClientClosedError,
    CodexAppClientError,
    ConfigurationError,
    OutputValidationError,
    TurnFailedError,
    TurnTimeoutError,
    UnsafeRpcError,
    UnsupportedServerRequest,
)
from codex_app_client.models import (
    ApprovalMode,
    CliMode,
    Event,
    InstructionMode,
    RunResult,
    RunSpec,
    Sandbox,
    SessionInfo,
)
from codex_app_client.policies import SAFE_RPC_METHODS, fail_closed_server_request

__all__ = [
    "SAFE_RPC_METHODS",
    "ActiveTurnError",
    "ApprovalMode",
    "CliMode",
    "Client",
    "ClientClosedError",
    "CodexAppClientError",
    "ConfigurationError",
    "Event",
    "InstructionMode",
    "OutputValidationError",
    "RunResult",
    "RunSpec",
    "Sandbox",
    "Session",
    "SessionInfo",
    "StartOptions",
    "TurnFailedError",
    "TurnTimeoutError",
    "UnsupportedServerRequest",
    "UnsafeRpcError",
    "__version__",
    "build_thread_params",
    "fail_closed_server_request",
]
