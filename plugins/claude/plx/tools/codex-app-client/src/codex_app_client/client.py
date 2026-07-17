# Public Client / Session API for Codex app-server.
# USAGE:
#   with Client() as client:
#       session = client.start(cwd=".", sandbox="workspace-write", approvals="deny-all")
#       result = session.run("Fix the failing tests.", timeout_seconds=300)

from __future__ import annotations

import json
import threading
from collections.abc import Iterator, Mapping
from pathlib import Path
from typing import Any, TypeVar

from pydantic import BaseModel, ValidationError

from codex_app_client._driver import Driver, JsonObject, ServerRequestHandler
from codex_app_client.errors import (
    ActiveTurnError,
    ClientClosedError,
    ConfigurationError,
    OutputValidationError,
    TurnFailedError,
    TurnTimeoutError,
)
from codex_app_client.models import (
    ApprovalMode,
    Event,
    InstructionMode,
    RunResult,
    RunSpec,
    Sandbox,
    SessionInfo,
)
from codex_app_client.policies import (
    approval_params,
    assert_rpc_allowed,
    fail_closed_server_request,
    full_access_allowed,
    sandbox_param,
)
from codex_app_client.prompts import load_headless_instructions

# --------------------------------------------------------------------------- #
# Types
# --------------------------------------------------------------------------- #

ModelT = TypeVar("ModelT", bound=BaseModel)

DEFAULT_INTERRUPT_GRACE_SECONDS = 10.0

# --------------------------------------------------------------------------- #
# Session options
# --------------------------------------------------------------------------- #


class StartOptions(BaseModel):
    """Normalized options for start / resume / fork.

    Fields left as ``None`` are omitted from the wire payload so resume/fork can
    leave existing thread settings unchanged.
    """

    cwd: Path | None = None
    sandbox: Sandbox | None = None
    approvals: ApprovalMode | None = None
    instructions: InstructionMode | str | None = None
    base_instructions: str | None = None
    model: str | None = None
    service_name: str | None = None
    ephemeral: bool | None = None
    unsafe: bool = False


def build_thread_params(options: StartOptions) -> dict[str, Any]:
    """Build app-server thread lifecycle params, omitting unset values."""
    if options.sandbox is Sandbox.FULL_ACCESS and not full_access_allowed(
        unsafe=options.unsafe
    ):
        raise ConfigurationError(
            "full-access sandbox requires unsafe=True and CODEX_APP_CLIENT_UNSAFE=1"
        )

    params: dict[str, Any] = {}

    if options.cwd is not None:
        params["cwd"] = str(options.cwd.resolve())

    if options.sandbox is not None:
        params["sandbox"] = sandbox_param(options.sandbox)

    if options.ephemeral is not None:
        params["ephemeral"] = options.ephemeral

    if options.approvals is not None:
        params.update(approval_params(options.approvals))

    if options.model is not None:
        params["model"] = options.model

    if options.service_name is not None:
        params["serviceName"] = options.service_name

    if options.instructions is not None:
        developer = _developer_instructions(options.instructions)
        if developer is not None:
            params["developerInstructions"] = developer

    if options.base_instructions is not None:
        params["baseInstructions"] = options.base_instructions

    return params


def _developer_instructions(instructions: InstructionMode | str) -> str | None:
    if instructions is InstructionMode.NATIVE:
        return None
    if instructions is InstructionMode.HEADLESS:
        return load_headless_instructions()
    if isinstance(instructions, str):
        return instructions
    return None


def _session_info_from_response(response: Any) -> SessionInfo:
    instruction_sources = []
    raw_sources = getattr(response, "instruction_sources", None) or []
    for path in raw_sources:
        instruction_sources.append(Path(_absolute_path(path)))

    approvals_reviewer = getattr(response, "approvals_reviewer", None)
    reviewer_value = (
        approvals_reviewer.value
        if approvals_reviewer is not None and hasattr(approvals_reviewer, "value")
        else (str(approvals_reviewer) if approvals_reviewer is not None else None)
    )

    sandbox = getattr(response, "sandbox", None)
    approval_policy = getattr(response, "approval_policy", None)

    return SessionInfo(
        thread_id=response.thread.id,
        cwd=Path(_absolute_path(response.cwd)),
        model=response.model,
        model_provider=getattr(response, "model_provider", None),
        instruction_sources=instruction_sources,
        sandbox=_dump_model(sandbox),
        approval_policy=_dump_model(approval_policy),
        approvals_reviewer=reviewer_value,
    )


def _absolute_path(value: Any) -> str:
    if hasattr(value, "root"):
        return str(value.root)
    return str(value)


def _dump_model(value: Any) -> Any:
    if value is None:
        return None
    if hasattr(value, "model_dump"):
        return value.model_dump(by_alias=True, mode="json")
    if hasattr(value, "value"):
        return value.value
    return value


def _normalize_sandbox(value: Sandbox | str) -> Sandbox:
    return value if isinstance(value, Sandbox) else Sandbox(value)


def _normalize_approvals(value: ApprovalMode | str) -> ApprovalMode:
    return value if isinstance(value, ApprovalMode) else ApprovalMode(value)


def _normalize_instructions(
    value: InstructionMode | str | Path,
) -> InstructionMode | str:
    if isinstance(value, InstructionMode):
        return value
    if isinstance(value, Path):
        return value.read_text(encoding="utf-8")
    if value in {InstructionMode.NATIVE.value, InstructionMode.HEADLESS.value}:
        return InstructionMode(value)
    path = Path(value)
    if path.is_file():
        return path.read_text(encoding="utf-8")
    return value


# --------------------------------------------------------------------------- #
# Event / result helpers
# --------------------------------------------------------------------------- #


def normalize_event(notification: Any) -> Event:
    """Convert an SDK Notification into a stable Event model."""
    method = notification.method
    payload_obj = notification.payload
    payload = _payload_to_dict(payload_obj)

    thread_id = payload.get("threadId") or payload.get("thread_id")
    turn_id = payload.get("turnId") or payload.get("turn_id")
    if turn_id is None and isinstance(payload.get("turn"), dict):
        turn_id = payload["turn"].get("id")

    return Event(
        method=method,
        thread_id=str(thread_id) if thread_id is not None else None,
        turn_id=str(turn_id) if turn_id is not None else None,
        payload=payload,
    )


def _payload_to_dict(payload: Any) -> dict[str, Any]:
    if payload is None:
        return {}
    if isinstance(payload, dict):
        return payload
    # SDK UnknownNotification is a slots dataclass with `.params`.
    params = getattr(payload, "params", None)
    if isinstance(params, dict):
        return params
    if hasattr(payload, "model_dump"):
        dumped = payload.model_dump(by_alias=True, mode="json")
        if isinstance(dumped, dict):
            return dumped
    try:
        return dict(vars(payload))
    except TypeError:
        pass
    return {"value": str(payload)}


def _item_to_dict(item: Any) -> dict[str, Any]:
    if isinstance(item, dict):
        return item
    if hasattr(item, "model_dump"):
        dumped = item.model_dump(by_alias=True, mode="json")
        if isinstance(dumped, dict):
            return dumped
    return {"value": item}


def _final_assistant_response_from_items(items: list[dict[str, Any]]) -> str | None:
    """Prefer phase=final_answer agent messages, else latest phase-less agent message."""
    last_unknown_phase: str | None = None

    for item in reversed(items):
        root = item.get("root", item) if isinstance(item, dict) else item
        if not isinstance(root, dict):
            # Flatten RootModel dumps that use a typed envelope.
            continue

        item_type = root.get("type") or item.get("type")
        # Agent messages may be nested under type keys after alias dump.
        candidate = root
        if item_type not in {None, "agentMessage", "agent_message"} and "text" not in root:
            # Try one-level unwrap common for tagged unions.
            for value in root.values():
                if isinstance(value, dict) and (
                    value.get("type") in {"agentMessage", "agent_message"}
                    or "text" in value
                    and value.get("type") is None
                    and "phase" in value
                ):
                    candidate = value
                    item_type = candidate.get("type")
                    break

        text = candidate.get("text")
        if not isinstance(text, str):
            continue

        # Only treat items that look like agent messages.
        if item_type not in {None, "agentMessage", "agent_message"} and "phase" not in candidate:
            # If text exists without a type, still consider it when phase is present
            # or when the outer type is clearly agent-related.
            if "phase" not in candidate and item_type is not None:
                continue

        phase = candidate.get("phase")
        if phase in {"final_answer", "finalAnswer"}:
            return text
        if phase is None and last_unknown_phase is None:
            last_unknown_phase = text

    return last_unknown_phase


def collect_from_events(
    events: Iterator[Event],
    *,
    thread_id: str,
    turn_id: str,
    require_completed: bool = True,
) -> RunResult:
    """Collect a RunResult from a stream of normalized events.

    When ``require_completed`` is true (default), any terminal status other than
    ``completed`` raises ``TurnFailedError``. Pass ``require_completed=False`` to
    build a partial result after interrupt/timeout for inspection only.
    """
    items: list[dict[str, Any]] = []
    usage: dict[str, Any] | None = None
    completed_payload: dict[str, Any] | None = None

    for event in events:
        if event.method == "item/completed" and event.turn_id == turn_id:
            item = event.payload.get("item")
            if item is not None:
                items.append(_item_to_dict(item))
            continue

        if (
            event.method in {"thread/tokenUsage/updated", "thread/tokenUsageUpdated"}
            and event.turn_id == turn_id
        ):
            usage_value = event.payload.get("tokenUsage") or event.payload.get(
                "token_usage"
            )
            if isinstance(usage_value, dict):
                usage = usage_value
            continue

        if event.method == "turn/completed" and event.turn_id == turn_id:
            completed_payload = event.payload

    if completed_payload is None:
        raise TurnFailedError("turn completed event not received")

    turn = completed_payload.get("turn") or {}
    status = str(turn.get("status") or "unknown")
    error = turn.get("error")
    if isinstance(error, dict):
        error_dict: dict[str, Any] | None = error
    elif error is None:
        error_dict = None
    else:
        error_dict = {"message": str(error)}

    final_response = _final_assistant_response_from_items(items)

    result = RunResult(
        thread_id=thread_id,
        turn_id=turn_id,
        status=status,
        final_response=final_response,
        items=items,
        usage=usage,
        error=error_dict,
        started_at=turn.get("startedAt") or turn.get("started_at"),
        completed_at=turn.get("completedAt") or turn.get("completed_at"),
        duration_ms=turn.get("durationMs") or turn.get("duration_ms"),
    )

    if require_completed and status != "completed":
        message = None
        if error_dict is not None:
            message = error_dict.get("message")
        raise TurnFailedError(
            str(message or f"turn ended with status {status!r}"),
            error=error_dict,
            status=status,
            result=result,
        )

    return result


# --------------------------------------------------------------------------- #
# Client
# --------------------------------------------------------------------------- #


class Client:
    """One app-server subprocess. Reuse across multiple Session threads."""

    def __init__(
        self,
        *,
        codex_bin: Path | None = None,
        env: Mapping[str, str] | None = None,
        config_overrides: Mapping[str, object] | tuple[str, ...] | None = None,
        experimental: bool = False,
        server_request_handler: ServerRequestHandler | None = None,
        launch_args_override: tuple[str, ...] | None = None,
        cwd: Path | None = None,
    ) -> None:
        handler = server_request_handler or fail_closed_server_request
        overrides = _format_config_overrides(config_overrides)

        self._driver = Driver(
            server_request_handler=handler,
            cwd=cwd,
            env=env,
            codex_bin=codex_bin,
            config_overrides=overrides,
            experimental=experimental,
            launch_args_override=launch_args_override,
        )
        self._closed = False
        self._active_turns: dict[str, str] = {}
        self._turn_guard = threading.Lock()
        self._close_lock = threading.Lock()

    def __enter__(self) -> Client:
        return self

    def __exit__(self, *exc: object) -> None:
        self.close()

    @property
    def metadata(self) -> Any:
        self._ensure_open()
        return self._driver.metadata

    @property
    def closed(self) -> bool:
        return self._closed

    def close(self) -> None:
        """Close the app-server subprocess.

        After close, all sessions on this client are unusable. Hard turn timeouts
        that exhaust the interrupt grace period also close the client.
        """
        with self._close_lock:
            if self._closed:
                return
            self._closed = True
            self._driver.close()

    def _ensure_open(self) -> None:
        if self._closed:
            raise ClientClosedError(
                "Client is closed; create a new Client (timeout may have closed it)"
            )

    def start(
        self,
        *,
        cwd: Path | str = ".",
        sandbox: Sandbox | str = Sandbox.READ_ONLY,
        approvals: ApprovalMode | str = ApprovalMode.DENY_ALL,
        instructions: InstructionMode | str | Path = InstructionMode.NATIVE,
        base_instructions: str | None = None,
        model: str | None = None,
        service_name: str | None = None,
        ephemeral: bool = True,
        unsafe: bool = False,
    ) -> Session:
        self._ensure_open()
        options = StartOptions(
            cwd=Path(cwd),
            sandbox=_normalize_sandbox(sandbox),
            approvals=_normalize_approvals(approvals),
            instructions=_normalize_instructions(instructions),
            base_instructions=base_instructions,
            model=model,
            service_name=service_name,
            ephemeral=ephemeral,
            unsafe=unsafe,
        )
        response = self._driver.thread_start(build_thread_params(options))
        info = _session_info_from_response(response)
        return Session(self, info, options)

    def resume(
        self,
        thread_id: str,
        *,
        cwd: Path | str | None = None,
        sandbox: Sandbox | str | None = None,
        approvals: ApprovalMode | str | None = None,
        instructions: InstructionMode | str | Path | None = None,
        model: str | None = None,
        unsafe: bool = False,
    ) -> Session:
        """Resume a thread. Only explicitly passed options are sent as overrides."""
        self._ensure_open()
        options = StartOptions(
            cwd=Path(cwd) if cwd is not None else None,
            sandbox=_normalize_sandbox(sandbox) if sandbox is not None else None,
            approvals=_normalize_approvals(approvals) if approvals is not None else None,
            instructions=(
                _normalize_instructions(instructions)
                if instructions is not None
                else None
            ),
            model=model,
            unsafe=unsafe,
        )
        response = self._driver.thread_resume(thread_id, build_thread_params(options))
        info = _session_info_from_response(response)
        return Session(self, info, options)

    def fork(
        self,
        thread_id: str,
        *,
        cwd: Path | str | None = None,
        sandbox: Sandbox | str | None = None,
        approvals: ApprovalMode | str | None = None,
        instructions: InstructionMode | str | Path | None = None,
        model: str | None = None,
        ephemeral: bool | None = None,
        unsafe: bool = False,
    ) -> Session:
        """Fork a thread. Only explicitly passed options are sent as overrides."""
        self._ensure_open()
        options = StartOptions(
            cwd=Path(cwd) if cwd is not None else None,
            sandbox=_normalize_sandbox(sandbox) if sandbox is not None else None,
            approvals=_normalize_approvals(approvals) if approvals is not None else None,
            instructions=(
                _normalize_instructions(instructions)
                if instructions is not None
                else None
            ),
            model=model,
            ephemeral=ephemeral,
            unsafe=unsafe,
        )
        response = self._driver.thread_fork(thread_id, build_thread_params(options))
        info = _session_info_from_response(response)
        return Session(self, info, options)

    def rpc(
        self,
        method: str,
        params: dict[str, Any] | None = None,
        *,
        unsafe: bool = False,
    ) -> dict[str, Any]:
        self._ensure_open()
        assert_rpc_allowed(method, unsafe=unsafe)
        return self._driver.rpc_object(method, params)

    # ------------------------------------------------------------------ #
    # Internal turn coordination
    # ------------------------------------------------------------------ #

    def _acquire_turn(self, thread_id: str, turn_id: str) -> None:
        with self._turn_guard:
            if thread_id in self._active_turns:
                raise ActiveTurnError(
                    f"thread {thread_id!r} already has active turn "
                    f"{self._active_turns[thread_id]!r}"
                )
            self._active_turns[thread_id] = turn_id

    def _release_turn(self, thread_id: str, turn_id: str) -> None:
        with self._turn_guard:
            current = self._active_turns.get(thread_id)
            if current == turn_id:
                del self._active_turns[thread_id]

    def _mark_turn_starting(self, thread_id: str) -> None:
        """Reserve the thread before turn/start returns a turn id."""
        with self._turn_guard:
            if thread_id in self._active_turns:
                raise ActiveTurnError(
                    f"thread {thread_id!r} already has active turn "
                    f"{self._active_turns[thread_id]!r}"
                )
            self._active_turns[thread_id] = "__starting__"

    def _replace_starting_turn(self, thread_id: str, turn_id: str) -> None:
        with self._turn_guard:
            self._active_turns[thread_id] = turn_id


# --------------------------------------------------------------------------- #
# Session
# --------------------------------------------------------------------------- #


class Session:
    """A single Codex thread with run / stream / steer / interrupt helpers."""

    def __init__(
        self,
        client: Client,
        info: SessionInfo,
        options: StartOptions,
    ) -> None:
        self._client = client
        self._info = info
        self._options = options
        self._current_turn_id: str | None = None
        self._local_lock = threading.Lock()

    # -- properties ---------------------------------------------------- #

    @property
    def thread_id(self) -> str:
        return self._info.thread_id

    @property
    def cwd(self) -> Path:
        return self._info.cwd

    @property
    def model(self) -> str:
        return self._info.model

    @property
    def instruction_sources(self) -> list[Path]:
        return list(self._info.instruction_sources)

    @property
    def sandbox(self) -> dict[str, Any] | None:
        return self._info.sandbox

    @property
    def approvals(self) -> Any:
        return self._info.approval_policy

    @property
    def info(self) -> SessionInfo:
        return self._info

    # -- operations ---------------------------------------------------- #

    def stream(
        self,
        prompt: str | RunSpec,
        *,
        output_schema: dict[str, Any] | type[BaseModel] | None = None,
        effort: str | None = None,
    ) -> Iterator[Event]:
        """Start a turn and yield events until turn/completed."""
        self._client._ensure_open()
        schema = _coerce_output_schema(output_schema)
        if isinstance(prompt, RunSpec):
            text = prompt.render(include_output_schema_instruction=schema is not None)
        else:
            text = prompt

        self._client._mark_turn_starting(self.thread_id)
        turn_id: str | None = None
        try:
            params: JsonObject = {}
            if schema is not None:
                params["outputSchema"] = schema
            if effort is not None:
                params["effort"] = effort

            started = self._client._driver.turn_start(self.thread_id, text, params)
            turn_id = started.turn.id
            self._client._replace_starting_turn(self.thread_id, turn_id)
            with self._local_lock:
                self._current_turn_id = turn_id

            while True:
                notification = self._client._driver.next_turn_notification(turn_id)
                event = normalize_event(notification)
                yield event
                if event.method == "turn/completed" and event.turn_id == turn_id:
                    break
        finally:
            if turn_id is not None:
                self._client._driver.unregister_turn(turn_id)
                self._client._release_turn(self.thread_id, turn_id)
            else:
                self._client._release_turn(self.thread_id, "__starting__")
            with self._local_lock:
                if self._current_turn_id == turn_id:
                    self._current_turn_id = None

    def run(
        self,
        prompt: str | RunSpec,
        *,
        output_model: type[ModelT] | None = None,
        output_schema: dict[str, Any] | None = None,
        timeout_seconds: float | None = None,
        interrupt_grace_seconds: float = DEFAULT_INTERRUPT_GRACE_SECONDS,
        effort: str | None = None,
    ) -> RunResult:
        """Collect a full turn into a RunResult, optionally with structured output.

        Returns only when the turn status is ``completed``. Failed or interrupted
        turns raise ``TurnFailedError``. Timeouts raise ``TurnTimeoutError``.
        """
        schema: dict[str, Any] | type[BaseModel] | None = output_schema
        if output_model is not None:
            schema = output_model

        if timeout_seconds is None:
            events = list(self.stream(prompt, output_schema=schema, effort=effort))
            result = collect_from_events(
                iter(events),
                thread_id=self.thread_id,
                turn_id=_turn_id_from_events(events),
            )
        else:
            result = self._run_with_timeout(
                prompt,
                output_schema=schema,
                timeout_seconds=timeout_seconds,
                interrupt_grace_seconds=interrupt_grace_seconds,
                effort=effort,
            )

        if output_model is not None:
            if result.final_response is None:
                raise OutputValidationError(
                    "turn completed without a final response to validate",
                    final_response=None,
                )
            try:
                result.output = output_model.model_validate_json(result.final_response)
            except ValidationError as exc:
                raise OutputValidationError(
                    f"structured output failed validation: {exc}",
                    final_response=result.final_response,
                ) from exc

        return result

    def steer(self, prompt: str) -> None:
        """Inject additional input into the active turn."""
        self._client._ensure_open()
        with self._local_lock:
            turn_id = self._current_turn_id
        if turn_id is None:
            raise ActiveTurnError("no active turn to steer")
        self._client._driver.turn_steer(self.thread_id, turn_id, prompt)

    def interrupt(self) -> None:
        """Request interruption of the active turn."""
        self._client._ensure_open()
        with self._local_lock:
            turn_id = self._current_turn_id
        if turn_id is None:
            raise ActiveTurnError("no active turn to interrupt")
        self._client._driver.turn_interrupt(self.thread_id, turn_id)

    def read(self, *, include_turns: bool = False) -> dict[str, Any]:
        """Read the current thread state via the typed SDK method."""
        self._client._ensure_open()
        response = self._client._driver.thread_read(
            self.thread_id,
            include_turns=include_turns,
        )
        return _dump_model(response) or {}

    # -- timeout path -------------------------------------------------- #

    def _run_with_timeout(
        self,
        prompt: str | RunSpec,
        *,
        output_schema: dict[str, Any] | type[BaseModel] | None,
        timeout_seconds: float,
        interrupt_grace_seconds: float,
        effort: str | None,
    ) -> RunResult:
        events: list[Event] = []
        error_box: list[BaseException] = []
        done = threading.Event()

        def worker() -> None:
            try:
                for event in self.stream(
                    prompt, output_schema=output_schema, effort=effort
                ):
                    events.append(event)
            except BaseException as exc:  # noqa: BLE001 - surface to caller
                error_box.append(exc)
            finally:
                done.set()

        thread = threading.Thread(target=worker, name="cxa-turn-worker", daemon=True)
        thread.start()

        if done.wait(timeout_seconds):
            thread.join(timeout=1)
            if error_box:
                raise error_box[0]
            return collect_from_events(
                iter(events),
                thread_id=self.thread_id,
                turn_id=_turn_id_from_events(events),
            )

        # Deadline exceeded: always prefer timeout semantics after this point.
        try:
            self.interrupt()
        except Exception:
            pass

        if done.wait(timeout=interrupt_grace_seconds):
            thread.join(timeout=1)
            partial = _partial_result_from_events(events, thread_id=self.thread_id)
            raise TurnTimeoutError(
                f"turn exceeded {timeout_seconds}s; interrupted after deadline",
                partial=partial,
                client_closed=False,
            )

        # Interrupt did not finish — close the whole app-server process.
        # Documented as client-fatal: other sessions on this Client die too.
        self._client.close()
        partial = _partial_result_from_events(events, thread_id=self.thread_id)
        raise TurnTimeoutError(
            f"turn exceeded {timeout_seconds}s; client closed after interrupt "
            f"grace period (all sessions on this Client are unusable)",
            partial=partial,
            client_closed=True,
        )


# --------------------------------------------------------------------------- #
# Helpers
# --------------------------------------------------------------------------- #


def _format_config_overrides(
    overrides: Mapping[str, object] | tuple[str, ...] | list[str] | None,
) -> tuple[str, ...]:
    if overrides is None:
        return ()
    if isinstance(overrides, (tuple, list)):
        return tuple(str(item) for item in overrides)
    result: list[str] = []
    for key, value in overrides.items():
        if isinstance(value, str):
            result.append(f"{key}={value}")
        else:
            result.append(f"{key}={json.dumps(value)}")
    return tuple(result)


def _coerce_output_schema(
    schema: dict[str, Any] | type[BaseModel] | None,
) -> dict[str, Any] | None:
    if schema is None:
        return None
    if isinstance(schema, dict):
        return schema
    generated = schema.model_json_schema()
    _close_object_schemas(generated)
    return generated


def _close_object_schemas(value: Any) -> None:
    """Make Pydantic object schemas compatible with strict structured output."""
    if isinstance(value, dict):
        if value.get("type") == "object":
            value["additionalProperties"] = False
        for child in value.values():
            _close_object_schemas(child)
    elif isinstance(value, list):
        for child in value:
            _close_object_schemas(child)


def _turn_id_from_events(events: list[Event]) -> str:
    for event in reversed(events):
        if event.turn_id:
            return event.turn_id
    raise TurnFailedError("no turn_id observed in event stream")


def _partial_result_from_events(
    events: list[Event],
    *,
    thread_id: str,
) -> RunResult | None:
    if not events:
        return None
    try:
        turn_id = _turn_id_from_events(events)
        return collect_from_events(
            iter(events),
            thread_id=thread_id,
            turn_id=turn_id,
            require_completed=False,
        )
    except Exception:
        return None
