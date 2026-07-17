# Policy mapping and fail-closed server-request handling.
# USAGE:
#   from codex_app_client.policies import (
#       fail_closed_server_request,
#       approval_params,
#       sandbox_param,
#       SAFE_RPC_METHODS,
#   )

from __future__ import annotations

import os
from typing import Any

from codex_app_client.errors import UnsafeRpcError, UnsupportedServerRequest
from codex_app_client.models import ApprovalMode, CliMode, Sandbox

# --------------------------------------------------------------------------- #
# Constants
# --------------------------------------------------------------------------- #

JsonObject = dict[str, Any]

SAFE_RPC_METHODS: frozenset[str] = frozenset(
    {
        "account/read",
        "model/list",
        "thread/read",
        "thread/list",
        "thread/loaded/list",
        "skills/list",
        "config/read",
        "configRequirements/read",
    }
)

FORBIDDEN_RPC_METHODS: frozenset[str] = frozenset(
    {
        "initialize",
        "initialized",
    }
)

UNSAFE_ENV_VAR = "CODEX_APP_CLIENT_UNSAFE"

# --------------------------------------------------------------------------- #
# Server-request handler
# --------------------------------------------------------------------------- #


def fail_closed_server_request(
    method: str,
    params: JsonObject | None,
) -> JsonObject:
    """Decline approvals and reject every other server-initiated request.

    Never call methods on the same CodexClient from this handler: it runs on
    the client's sole reader thread and can deadlock.
    """
    del params

    if method == "item/commandExecution/requestApproval":
        return {"decision": "decline"}

    if method == "item/fileChange/requestApproval":
        return {"decision": "decline"}

    raise UnsupportedServerRequest(method)


# --------------------------------------------------------------------------- #
# Wire mapping
# --------------------------------------------------------------------------- #


def approval_params(mode: ApprovalMode) -> dict[str, Any]:
    """Map public approval modes to app-server start parameters."""
    if mode is ApprovalMode.DENY_ALL:
        return {"approvalPolicy": "never"}

    if mode is ApprovalMode.AUTO_REVIEW:
        return {
            "approvalPolicy": "on-request",
            "approvalsReviewer": "auto_review",
        }

    raise AssertionError(f"Unhandled approval mode: {mode}")


def sandbox_param(mode: Sandbox) -> str:
    """Map public sandbox presets to wire-level sandbox mode strings."""
    mapping = {
        Sandbox.READ_ONLY: "read-only",
        Sandbox.WORKSPACE_WRITE: "workspace-write",
        Sandbox.FULL_ACCESS: "danger-full-access",
    }
    return mapping[mode]


def cli_mode_policy(mode: CliMode) -> tuple[Sandbox, ApprovalMode]:
    """Map CLI convenience modes to sandbox + approval policy."""
    if mode is CliMode.INSPECT:
        return Sandbox.READ_ONLY, ApprovalMode.DENY_ALL
    if mode is CliMode.EDIT:
        return Sandbox.WORKSPACE_WRITE, ApprovalMode.AUTO_REVIEW
    if mode is CliMode.CI_EDIT:
        return Sandbox.WORKSPACE_WRITE, ApprovalMode.DENY_ALL
    raise AssertionError(f"Unhandled CLI mode: {mode}")


# --------------------------------------------------------------------------- #
# RPC gate
# --------------------------------------------------------------------------- #


def assert_rpc_allowed(method: str, *, unsafe: bool = False) -> None:
    """Enforce the dual-gated raw RPC allowlist.

    Handshake methods are always blocked. Non-allowlisted methods require both
    ``unsafe=True`` and ``CODEX_APP_CLIENT_UNSAFE=1``.
    """
    if method in FORBIDDEN_RPC_METHODS:
        raise UnsafeRpcError(f"{method!r} is owned by the client lifecycle")

    if method in SAFE_RPC_METHODS:
        return

    enabled = os.environ.get(UNSAFE_ENV_VAR) == "1"
    if not unsafe or not enabled:
        raise UnsafeRpcError(
            f"{method!r} requires unsafe=True and {UNSAFE_ENV_VAR}=1"
        )


def full_access_allowed(*, unsafe: bool) -> bool:
    """Full-access sandbox requires the same dual gate as unsafe RPC."""
    return unsafe and os.environ.get(UNSAFE_ENV_VAR) == "1"
