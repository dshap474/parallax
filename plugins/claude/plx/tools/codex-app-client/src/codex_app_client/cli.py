# Machine-oriented CLI (`cxa`) for agents and non-Python callers.
# USAGE:
#   cxa doctor
#   cxa init --stdout
#   echo "Fix tests" | cxa run --mode inspect --ephemeral --stream
#   cxa rpc model/list

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, NoReturn

from codex_app_client import __version__
from codex_app_client.client import Client, collect_from_events
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
    InstructionMode,
    RunSpec,
    Sandbox,
)
from codex_app_client.policies import cli_mode_policy, full_access_allowed
from codex_app_client.prompts import load_agents_template

# --------------------------------------------------------------------------- #
# Exit codes
# --------------------------------------------------------------------------- #

EXIT_OK = 0
EXIT_USAGE = 2
EXIT_AUTH_CONFIG = 3
EXIT_DENIED = 4
EXIT_TURN_FAILED = 5
EXIT_TIMEOUT = 6
EXIT_PROTOCOL = 7
EXIT_OUTPUT_VALIDATION = 8
EXIT_UNSUPPORTED_REQUEST = 9

# --------------------------------------------------------------------------- #
# Argparse
# --------------------------------------------------------------------------- #


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="cxa",
        description="Thin machine-oriented client for Codex app-server",
    )
    parser.add_argument("--version", action="version", version=f"cxa {__version__}")
    sub = parser.add_subparsers(dest="command", required=True)

    run = sub.add_parser("run", help="Start or resume a thread and run one turn")
    run.add_argument("--cwd", type=Path, default=Path("."))
    run.add_argument("--thread", dest="thread_id", default=None)
    run.add_argument("--model", default=None)
    run.add_argument(
        "--mode",
        choices=[m.value for m in CliMode],
        default=CliMode.INSPECT.value,
    )
    run.add_argument(
        "--sandbox",
        choices=[s.value for s in Sandbox],
        default=None,
        help="Override mode sandbox (full-access requires --unsafe)",
    )
    run.add_argument(
        "--approvals",
        choices=[a.value for a in ApprovalMode],
        default=None,
        help="Override mode approval policy",
    )
    run.add_argument(
        "--instructions",
        default=InstructionMode.NATIVE.value,
        help="native | headless | path to developer instructions file",
    )
    run.add_argument("--schema", type=Path, default=None, help="JSON Schema file path")
    run.add_argument("--timeout", type=float, default=None)
    run.add_argument("--stream", action="store_true")
    run.add_argument("--prompt", default=None, help="Prompt text; otherwise read stdin")
    run.add_argument("--objective", default=None, help="Build a RunSpec from sections")
    run.add_argument("--constraint", action="append", default=[])
    run.add_argument("--acceptance", action="append", default=[])
    run.add_argument("--validation", action="append", default=[])
    persistence = run.add_mutually_exclusive_group()
    persistence.add_argument(
        "--ephemeral",
        dest="ephemeral",
        action="store_true",
        default=True,
        help="Do not persist a resumable thread (default for new threads)",
    )
    persistence.add_argument(
        "--persistent",
        dest="ephemeral",
        action="store_false",
        help="Persist a new thread so it can be resumed later",
    )
    run.add_argument(
        "--unsafe",
        action="store_true",
        help="Allow full-access when CODEX_APP_CLIENT_UNSAFE=1",
    )
    run.add_argument("--experimental", action="store_true")
    run.set_defaults(func=cmd_run)

    rpc = sub.add_parser("rpc", help="Call a raw app-server method (allowlisted)")
    rpc.add_argument("method")
    rpc.add_argument(
        "--params",
        default=None,
        help="JSON object string, or omit to read JSON from stdin",
    )
    rpc.add_argument("--unsafe", action="store_true")
    rpc.add_argument("--experimental", action="store_true")
    rpc.set_defaults(func=cmd_rpc)

    init = sub.add_parser("init", help="Write an AGENTS.md template into the cwd")
    init.add_argument("--stdout", action="store_true")
    init.add_argument("--force", action="store_true")
    init.add_argument("--cwd", type=Path, default=Path("."))
    init.set_defaults(func=cmd_init)

    doctor = sub.add_parser(
        "doctor",
        help="Start an ephemeral read-only thread and report instruction sources",
    )
    doctor.add_argument("--cwd", type=Path, default=Path("."))
    doctor.add_argument("--model", default=None)
    doctor.add_argument("--experimental", action="store_true")
    doctor.set_defaults(func=cmd_doctor)

    bridge = sub.add_parser("bridge", help="Serve concurrent structured turns over NDJSON")
    bridge.add_argument("--workers", type=int, default=4)
    bridge.set_defaults(func=cmd_bridge)

    return parser


# --------------------------------------------------------------------------- #
# Commands
# --------------------------------------------------------------------------- #


def cmd_bridge(args: argparse.Namespace) -> int:
    if args.workers <= 0:
        raise ConfigurationError("--workers must be a positive integer")
    from codex_app_client.bridge import run_bridge

    return run_bridge(workers=args.workers)


def cmd_init(args: argparse.Namespace) -> int:
    template = load_agents_template()
    if args.stdout:
        sys.stdout.write(template)
        if not template.endswith("\n"):
            sys.stdout.write("\n")
        return EXIT_OK

    cwd = args.cwd.resolve()
    dest = cwd / "AGENTS.md"
    override = cwd / "AGENTS.override.md"
    if (dest.exists() or override.exists()) and not args.force:
        _eprint(
            f"refusing to overwrite existing {dest.name if dest.exists() else override.name}; "
            "pass --force to replace AGENTS.md"
        )
        return EXIT_USAGE

    dest.write_text(template, encoding="utf-8")
    _emit({"written": str(dest)})
    return EXIT_OK


def cmd_doctor(args: argparse.Namespace) -> int:
    try:
        with Client(experimental=args.experimental) as client:
            session = client.start(
                cwd=args.cwd,
                sandbox=Sandbox.READ_ONLY,
                approvals=ApprovalMode.DENY_ALL,
                instructions=InstructionMode.NATIVE,
                model=args.model,
                ephemeral=True,
            )
            payload = {
                "cwd": str(session.cwd),
                "thread_id": session.thread_id,
                "model": session.model,
                "sandbox": session.sandbox,
                "approval_policy": session.approvals,
                "instruction_sources": [str(p) for p in session.instruction_sources],
            }
            _emit(payload)
            return EXIT_OK
    except Exception as exc:
        return _handle_error(exc)


def cmd_rpc(args: argparse.Namespace) -> int:
    params = _load_params(args.params)
    try:
        with Client(experimental=args.experimental) as client:
            result = client.rpc(args.method, params, unsafe=args.unsafe)
            _emit(result)
            return EXIT_OK
    except Exception as exc:
        return _handle_error(exc)


def cmd_run(args: argparse.Namespace) -> int:
    try:
        sandbox, approvals = _resolve_run_policy(args)
        instructions = _resolve_instructions(args.instructions)
        prompt = _resolve_prompt(args)
        schema = _load_schema(args.schema)

        with Client(experimental=args.experimental) as client:
            if args.thread_id:
                session = client.resume(
                    args.thread_id,
                    cwd=args.cwd,
                    sandbox=sandbox,
                    approvals=approvals,
                    instructions=instructions,
                    model=args.model,
                    unsafe=args.unsafe,
                )
            else:
                session = client.start(
                    cwd=args.cwd,
                    sandbox=sandbox,
                    approvals=approvals,
                    instructions=instructions,
                    model=args.model,
                    ephemeral=args.ephemeral,
                    unsafe=args.unsafe,
                )

            if args.stream:
                if args.timeout is not None:
                    raise ConfigurationError(
                        "--timeout is not supported with --stream; "
                        "omit --stream for timed runs"
                    )
                events = []
                for event in session.stream(prompt, output_schema=schema):
                    _emit(event.model_dump(mode="json"))
                    events.append(event)
                return _exit_from_stream_events(events, thread_id=session.thread_id)

            result = session.run(
                prompt,
                output_schema=schema,
                timeout_seconds=args.timeout,
            )
            _emit(result.model_dump(mode="json"))
            return _exit_from_status(result.status)
    except Exception as exc:
        return _handle_error(exc)


# --------------------------------------------------------------------------- #
# Helpers
# --------------------------------------------------------------------------- #


def _resolve_run_policy(args: argparse.Namespace) -> tuple[Sandbox, ApprovalMode]:
    mode = CliMode(args.mode)
    sandbox, approvals = cli_mode_policy(mode)

    if args.sandbox is not None:
        sandbox = Sandbox(args.sandbox)
    if args.approvals is not None:
        approvals = ApprovalMode(args.approvals)

    if sandbox is Sandbox.FULL_ACCESS and not full_access_allowed(unsafe=args.unsafe):
        raise ConfigurationError(
            "full-access requires --unsafe and CODEX_APP_CLIENT_UNSAFE=1"
        )

    return sandbox, approvals


def _resolve_instructions(value: str) -> InstructionMode | str:
    if value in {InstructionMode.NATIVE.value, InstructionMode.HEADLESS.value}:
        return InstructionMode(value)
    path = Path(value)
    if path.is_file():
        return path.read_text(encoding="utf-8")
    raise ConfigurationError(f"instructions path not found: {value}")


def _resolve_prompt(args: argparse.Namespace) -> str | RunSpec:
    if args.objective:
        return RunSpec(
            objective=args.objective,
            constraints=list(args.constraint),
            acceptance_criteria=list(args.acceptance),
            validation=list(args.validation),
        )
    if args.prompt is not None:
        return args.prompt
    if not sys.stdin.isatty():
        text = sys.stdin.read()
        if text.strip():
            return text
    raise ConfigurationError("provide --prompt, --objective, or prompt on stdin")


def _load_schema(path: Path | None) -> dict[str, Any] | None:
    if path is None:
        return None
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ConfigurationError("--schema must contain a JSON object")
    return data


def _load_params(raw: str | None) -> dict[str, Any] | None:
    if raw is None:
        if sys.stdin.isatty():
            return None
        text = sys.stdin.read().strip()
        if not text:
            return None
        data = json.loads(text)
    else:
        data = json.loads(raw)
    if data is None:
        return None
    if not isinstance(data, dict):
        raise ConfigurationError("RPC params must be a JSON object")
    return data


def _emit(payload: Any) -> None:
    sys.stdout.write(json.dumps(payload, default=str) + "\n")
    sys.stdout.flush()


def _eprint(message: str) -> None:
    sys.stderr.write(message + "\n")
    sys.stderr.flush()


def _exit_from_status(status: str) -> int:
    if status == "completed":
        return EXIT_OK
    if status in {"interrupted"}:
        return EXIT_TIMEOUT
    return EXIT_TURN_FAILED


def _exit_from_stream_events(events: list[Any], *, thread_id: str) -> int:
    """Map a finished event stream to a CLI exit code."""
    if not events:
        _eprint("stream ended without events")
        return EXIT_TURN_FAILED
    turn_id = None
    for event in reversed(events):
        if getattr(event, "turn_id", None):
            turn_id = event.turn_id
            break
    if turn_id is None:
        _eprint("stream ended without a turn_id")
        return EXIT_TURN_FAILED
    try:
        result = collect_from_events(
            iter(events),
            thread_id=thread_id,
            turn_id=turn_id,
            require_completed=True,
        )
    except TurnFailedError as exc:
        _eprint(str(exc))
        if exc.status == "interrupted":
            return EXIT_TIMEOUT
        return EXIT_TURN_FAILED
    return _exit_from_status(result.status)


def _handle_error(exc: BaseException) -> int:
    if isinstance(exc, (ConfigurationError, UnsafeRpcError, argparse.ArgumentError)):
        _eprint(str(exc))
        return EXIT_USAGE
    if isinstance(exc, UnsupportedServerRequest):
        _eprint(str(exc))
        return EXIT_UNSUPPORTED_REQUEST
    if isinstance(exc, OutputValidationError):
        _eprint(str(exc))
        return EXIT_OUTPUT_VALIDATION
    if isinstance(exc, TurnTimeoutError):
        _eprint(str(exc))
        if exc.partial is not None:
            _emit(exc.partial.model_dump(mode="json"))
        return EXIT_TIMEOUT
    if isinstance(exc, ClientClosedError):
        _eprint(str(exc))
        return EXIT_TIMEOUT
    if isinstance(exc, TurnFailedError):
        _eprint(str(exc))
        if exc.result is not None:
            _emit(exc.result.model_dump(mode="json"))
        if exc.status == "interrupted":
            return EXIT_TIMEOUT
        return EXIT_TURN_FAILED
    if isinstance(exc, ActiveTurnError):
        _eprint(str(exc))
        return EXIT_TURN_FAILED
    if isinstance(exc, CodexAppClientError):
        _eprint(str(exc))
        return EXIT_PROTOCOL

    # Heuristic mapping for SDK / auth failures
    message = str(exc).lower()
    name = type(exc).__name__.lower()
    if "auth" in message or "login" in message or "unauthorized" in message:
        _eprint(str(exc))
        return EXIT_AUTH_CONFIG
    if "denied" in message or "approval" in message or "permission" in message:
        _eprint(str(exc))
        return EXIT_DENIED
    if "config" in name or "invalid" in message:
        _eprint(str(exc))
        return EXIT_AUTH_CONFIG

    _eprint(f"{type(exc).__name__}: {exc}")
    return EXIT_PROTOCOL


# --------------------------------------------------------------------------- #
# Entry point
# --------------------------------------------------------------------------- #


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    try:
        args = parser.parse_args(argv)
    except SystemExit as exc:
        code = exc.code
        if code is None:
            return EXIT_OK
        return int(code) if isinstance(code, int) else EXIT_USAGE

    return int(args.func(args))


def _main() -> NoReturn:
    raise SystemExit(main())


if __name__ == "__main__":
    _main()
