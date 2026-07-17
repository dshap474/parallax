# Unit tests for Client.rpc dual gate (no subprocess).
# USAGE: uv run pytest tests/unit/test_rpc_guard.py

from __future__ import annotations

from typing import Any

import pytest

from codex_app_client.client import Client
from codex_app_client.errors import UnsafeRpcError


class _FakeDriver:
    def __init__(self) -> None:
        self.calls: list[tuple[str, dict[str, Any] | None]] = []
        self.metadata = {"ok": True}

    def rpc_object(self, method: str, params: dict[str, Any] | None) -> dict[str, Any]:
        self.calls.append((method, params))
        return {"method": method, "params": params}

    def close(self) -> None:
        return None


def _client_with_fake_driver(monkeypatch: pytest.MonkeyPatch) -> tuple[Client, _FakeDriver]:
    fake = _FakeDriver()

    def fake_driver_init(self: Any, **kwargs: Any) -> None:  # noqa: ANN401
        del kwargs
        self._client = None
        self.metadata = fake.metadata
        self._fake = fake

    def fake_rpc_object(self: Any, method: str, params: dict[str, Any] | None) -> dict[str, Any]:
        return fake.rpc_object(method, params)

    def fake_close(self: Any) -> None:
        return None

    monkeypatch.setattr(
        "codex_app_client.client.Driver.__init__",
        fake_driver_init,
    )
    monkeypatch.setattr(
        "codex_app_client.client.Driver.rpc_object",
        fake_rpc_object,
    )
    monkeypatch.setattr(
        "codex_app_client.client.Driver.close",
        fake_close,
    )
    client = Client()
    return client, fake


def test_client_rpc_allows_safe_methods(monkeypatch: pytest.MonkeyPatch) -> None:
    client, fake = _client_with_fake_driver(monkeypatch)
    result = client.rpc("model/list")
    assert result["method"] == "model/list"
    assert fake.calls == [("model/list", None)]
    client.close()


def test_client_rpc_blocks_unsafe_without_env(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("CODEX_APP_CLIENT_UNSAFE", raising=False)
    client, _fake = _client_with_fake_driver(monkeypatch)
    with pytest.raises(UnsafeRpcError):
        client.rpc("thread/shellCommand", unsafe=True)
    client.close()


def test_client_rpc_blocks_initialize_even_when_unsafe(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("CODEX_APP_CLIENT_UNSAFE", "1")
    client, _fake = _client_with_fake_driver(monkeypatch)
    with pytest.raises(UnsafeRpcError):
        client.rpc("initialize", unsafe=True)
    client.close()


def test_client_rpc_allows_unsafe_when_dual_gate_set(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("CODEX_APP_CLIENT_UNSAFE", "1")
    client, fake = _client_with_fake_driver(monkeypatch)
    result = client.rpc("thread/shellCommand", {"command": "echo hi"}, unsafe=True)
    assert result["method"] == "thread/shellCommand"
    assert fake.calls == [("thread/shellCommand", {"command": "echo hi"})]
    client.close()
