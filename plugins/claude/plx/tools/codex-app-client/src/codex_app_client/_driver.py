# Private adapter around openai_codex.client.CodexClient.
# USAGE:
#   Only imported by client.py. Callers use Client / Session, not Driver.

from __future__ import annotations

from collections.abc import Callable, Mapping
from pathlib import Path
from typing import Any

from openai_codex.client import CodexClient, CodexConfig
from pydantic import RootModel

from codex_app_client._version import __version__

# --------------------------------------------------------------------------- #
# Types
# --------------------------------------------------------------------------- #

JsonObject = dict[str, Any]
ServerRequestHandler = Callable[[str, JsonObject | None], JsonObject]


class ObjectResponse(RootModel[JsonObject]):
    """Generic JSON-object response model for raw RPC calls."""


# --------------------------------------------------------------------------- #
# Driver
# --------------------------------------------------------------------------- #


class Driver:
    """Owns one CodexClient / app-server subprocess lifecycle."""

    def __init__(
        self,
        *,
        server_request_handler: ServerRequestHandler,
        cwd: Path | None = None,
        env: Mapping[str, str] | None = None,
        codex_bin: Path | None = None,
        config_overrides: tuple[str, ...] = (),
        experimental: bool = False,
        launch_args_override: tuple[str, ...] | None = None,
    ) -> None:
        config = CodexConfig(
            codex_bin=str(codex_bin) if codex_bin is not None else None,
            launch_args_override=launch_args_override,
            config_overrides=config_overrides,
            cwd=str(cwd) if cwd is not None else None,
            env=dict(env) if env is not None else None,
            client_name="codex_app_client",
            client_title="Codex App Client",
            client_version=__version__,
            experimental_api=experimental,
        )

        self._client = CodexClient(
            config,
            approval_handler=server_request_handler,
        )
        self._client.start()
        self.metadata = self._client.initialize()

    def close(self) -> None:
        self._client.close()

    def thread_start(self, params: JsonObject):
        return self._client.thread_start(params)

    def thread_resume(self, thread_id: str, params: JsonObject):
        return self._client.thread_resume(thread_id, params)

    def thread_fork(self, thread_id: str, params: JsonObject):
        return self._client.thread_fork(thread_id, params)

    def thread_read(self, thread_id: str, *, include_turns: bool = False):
        return self._client.thread_read(thread_id, include_turns=include_turns)

    def turn_start(
        self,
        thread_id: str,
        prompt: str,
        params: JsonObject,
    ):
        return self._client.turn_start(thread_id, prompt, params)

    def turn_steer(
        self,
        thread_id: str,
        turn_id: str,
        prompt: str,
    ):
        return self._client.turn_steer(thread_id, turn_id, prompt)

    def turn_interrupt(self, thread_id: str, turn_id: str):
        return self._client.turn_interrupt(thread_id, turn_id)

    def next_turn_notification(self, turn_id: str):
        return self._client.next_turn_notification(turn_id)

    def unregister_turn(self, turn_id: str) -> None:
        self._client.unregister_turn_notifications(turn_id)

    def rpc_object(
        self,
        method: str,
        params: JsonObject | None,
    ) -> JsonObject:
        return self._client.request(
            method,
            params,
            response_model=ObjectResponse,
        ).root
