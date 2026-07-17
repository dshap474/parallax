# Unit tests for approval/sandbox mapping and fail-closed handling.
# USAGE: uv run pytest tests/unit/test_policies.py

from __future__ import annotations

import pytest

from codex_app_client.errors import UnsafeRpcError, UnsupportedServerRequest
from codex_app_client.models import ApprovalMode, CliMode, Sandbox
from codex_app_client.policies import (
    SAFE_RPC_METHODS,
    approval_params,
    assert_rpc_allowed,
    cli_mode_policy,
    fail_closed_server_request,
    full_access_allowed,
    sandbox_param,
)

# --------------------------------------------------------------------------- #
# Approval / sandbox mapping
# --------------------------------------------------------------------------- #


def test_approval_deny_all_maps_to_never() -> None:
    assert approval_params(ApprovalMode.DENY_ALL) == {"approvalPolicy": "never"}


def test_approval_auto_review_maps_to_on_request() -> None:
    assert approval_params(ApprovalMode.AUTO_REVIEW) == {
        "approvalPolicy": "on-request",
        "approvalsReviewer": "auto_review",
    }


def test_sandbox_mapping() -> None:
    assert sandbox_param(Sandbox.READ_ONLY) == "read-only"
    assert sandbox_param(Sandbox.WORKSPACE_WRITE) == "workspace-write"
    assert sandbox_param(Sandbox.FULL_ACCESS) == "danger-full-access"


def test_cli_mode_policy() -> None:
    assert cli_mode_policy(CliMode.INSPECT) == (Sandbox.READ_ONLY, ApprovalMode.DENY_ALL)
    assert cli_mode_policy(CliMode.EDIT) == (
        Sandbox.WORKSPACE_WRITE,
        ApprovalMode.AUTO_REVIEW,
    )
    assert cli_mode_policy(CliMode.CI_EDIT) == (
        Sandbox.WORKSPACE_WRITE,
        ApprovalMode.DENY_ALL,
    )


# --------------------------------------------------------------------------- #
# Fail-closed server requests
# --------------------------------------------------------------------------- #


def test_fail_closed_declines_command_approval() -> None:
    result = fail_closed_server_request(
        "item/commandExecution/requestApproval",
        {"command": "rm -rf /"},
    )
    assert result == {"decision": "decline"}


def test_fail_closed_declines_file_change_approval() -> None:
    result = fail_closed_server_request(
        "item/fileChange/requestApproval",
        {"paths": ["a.py"]},
    )
    assert result == {"decision": "decline"}


def test_fail_closed_rejects_unknown_server_request() -> None:
    with pytest.raises(UnsupportedServerRequest) as exc:
        fail_closed_server_request("item/tool/requestUserInput", {})
    assert exc.value.method == "item/tool/requestUserInput"


# --------------------------------------------------------------------------- #
# RPC gate
# --------------------------------------------------------------------------- #


def test_safe_rpc_methods_allowed() -> None:
    for method in SAFE_RPC_METHODS:
        assert_rpc_allowed(method, unsafe=False)


def test_forbidden_rpc_always_blocked(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("CODEX_APP_CLIENT_UNSAFE", "1")
    with pytest.raises(UnsafeRpcError):
        assert_rpc_allowed("initialize", unsafe=True)
    with pytest.raises(UnsafeRpcError):
        assert_rpc_allowed("initialized", unsafe=True)


def test_unsafe_rpc_requires_dual_gate(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("CODEX_APP_CLIENT_UNSAFE", raising=False)
    with pytest.raises(UnsafeRpcError):
        assert_rpc_allowed("thread/shellCommand", unsafe=True)

    monkeypatch.setenv("CODEX_APP_CLIENT_UNSAFE", "1")
    with pytest.raises(UnsafeRpcError):
        assert_rpc_allowed("thread/shellCommand", unsafe=False)

    assert_rpc_allowed("thread/shellCommand", unsafe=True)


def test_full_access_dual_gate(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("CODEX_APP_CLIENT_UNSAFE", raising=False)
    assert full_access_allowed(unsafe=True) is False
    monkeypatch.setenv("CODEX_APP_CLIENT_UNSAFE", "1")
    assert full_access_allowed(unsafe=False) is False
    assert full_access_allowed(unsafe=True) is True
