"""Devin adapter: one explicit full-access Devin print-mode turn validated by its ATIF export.

Devin has no OS sandbox here; the generated config disables imports, updates
and subagents, and the prompt carries the runtime boundary and guidance list.
Devin runs in its own session/process group so an interrupt stops the whole
tree. Only an exact provider diagnostic on native stderr is classed retryable.

USAGE:
    from plx_engine import devin
    devin.run(lane)              # raises SystemExit(1|3|4) on failure
    devin.usage(export_path)     # normalized usage fields from the ATIF export
"""

from __future__ import annotations

import json
import os
import re
import shutil
import signal
import subprocess
import time
import traceback
from pathlib import Path

from .lane import (Interrupted, Lane, append, default_signals, document, emit_stderr, encode,
                   exit_status, grep, head, interrupt_signals, list_guidance, nonempty, read_bytes,
                   say, show_head, spawn, truncate, write_boundary_prompt)

# --------------------------------------------------------------------------- #
# Config, prompt text and patterns
# --------------------------------------------------------------------------- #

CONFIG = """{
  "permissions": {"allow": [], "deny": [], "ask": []},
  "read_config_from": {"cursor": false, "windsurf": false, "claude": false},
  "subagents_enabled": false,
  "auto_update": false,
  "attribution": false,
  "show_hints": false,
  "notify": "never",
  "theme_mode": "nocolor"
}
"""

BOUNDARY_INTRO = (
    "Devin has full host access. Before inspecting or changing a path, read the listed "
    "guidance that governs it. Root files apply repo-wide; nested files and rule files apply "
    "only to their subtree or declared paths. Full access does not expand the task; "
    "publication, deployment, credential changes, and external-system mutations require the "
    "user to authorize the exact action and target.")
GUIDANCE_EXTRA = ("*/.devin/rules/*.md", "*/.devin/skills/*/SKILL.md")

AUTH_PATTERN = "not logged in|please log in|authentication required|no credentials|devin auth login"
AUTH_MESSAGE = "plx-engine: Devin not authenticated — run `devin auth login`, then retry."
RETRY_HEADER = re.compile(
    r"^Error: Agent error: Client error: Protocol error \(invalid_argument\): "
    r"an internal error occurred \(trace ID: [0-9a-f]+\): ",
    re.MULTILINE,
)


# --------------------------------------------------------------------------- #
# Transport
# --------------------------------------------------------------------------- #


def run(lane: Lane) -> None:
    # Never preserve a prior successful answer when any validation or invocation
    # step fails, including missing binary and authentication checks.
    truncate(lane.out)
    truncate(lane.log)
    if shutil.which("devin") is None:
        say("plx-engine: Devin CLI not found — install it and run `devin auth login`, then retry.")
        raise SystemExit(1)

    config = lane.tmp("devin-config.json")
    export_file = lane.tmp("devin-export.json")
    raw = lane.tmp("devin-stdout.log")
    auth_log = lane.tmp("devin-auth.log")
    prompt = lane.tmp("devin-prompt.md")
    Path(config).write_text(CONFIG)
    write_boundary_prompt(lane, prompt, BOUNDARY_INTRO,
                          list_guidance(lane.repo, *GUIDANCE_EXTRA), None)
    env = dict(os.environ)
    env.pop("DEVIN_SANDBOX", None)

    auth_rc = auth_status(config, auth_log, env)
    if auth_rc != 0:
        if grep(AUTH_PATTERN, auth_log):
            say(AUTH_MESSAGE)
            raise SystemExit(3)
        say(f"plx-engine: `devin auth status` failed (exit {auth_rc})")
        raise SystemExit(1)

    argv = ["devin", "--config", config,
            "--permission-mode", "dangerous", "--respect-workspace-trust", "false",
            "--model", lane.model, "--prompt-file", prompt, "--export", export_file, "-p"]
    lane.begin(export_file)
    with open(raw, "wb") as out, open(lane.log, "wb") as log:
        rc = run_group(argv, out, log, lane.repo, env)

    # Only native stderr can classify a retry. Model stdout and exported answers
    # may quote errors. Require the exact provider diagnostic and JSON boolean.
    retryable = rc != 0 and rc < 128 and is_retryable(lane.log)
    auth_failure = grep(AUTH_PATTERN, lane.log)

    if nonempty(raw):
        append(lane.log, b"\n--- Devin print stdout ---\n" + read_bytes(raw))
    if rc != 0:
        if auth_failure:
            say(AUTH_MESSAGE)
            raise SystemExit(3)
        if retryable:
            say(f"plx-engine: Devin retryable internal protocol failure (exit {rc}); "
                "inspect partial work before a bounded retry")
            show_head(lane.log, 40)
            raise SystemExit(4)
        say(f"Devin invocation failed (exit {rc})")
        show_head(lane.log, 40)
        raise SystemExit(1)

    problem = terminal_response(export_file, lane.out)
    if problem is not None:
        say("plx-engine: Devin completed without a valid terminal response")
        emit_stderr(head(encode(problem), 20))
        raise SystemExit(1)


def auth_status(config: str, auth_log: str, env: dict) -> int:
    """`devin auth status` in the foreground; it is not an owned lane child."""
    with open(auth_log, "wb") as log:
        proc = spawn(["devin", "--config", config, "auth", "status"], stdin=None,
                     stdout=log, stderr=subprocess.STDOUT, env=env, background=False)
        if isinstance(proc, int):
            return proc
        return exit_status(proc.wait())


# --------------------------------------------------------------------------- #
# Process group ownership
# --------------------------------------------------------------------------- #


def run_group(argv: list, out, log, repo: str, env: dict) -> int:
    """Launch Devin in a new session/process group; an interrupt stops the group
    (TERM, then KILL) and exits 1 without retrying."""
    proc = spawn(argv, stdin=subprocess.DEVNULL, stdout=out, stderr=log, cwd=repo, env=env,
                 new_session=True)
    if isinstance(proc, int):
        return proc
    interrupt_signals()
    try:
        returncode = proc.wait()
    except Interrupted:
        default_signals()
        stop_group(proc, signal.SIGTERM)
        alive = stop_group(proc, signal.SIGKILL)
        if alive:
            say("plx-engine: Devin invocation interrupted; could not confirm that the owned "
                "process tree stopped")
        else:
            say("plx-engine: Devin invocation interrupted; the owned process tree was stopped "
                "and will not be retried")
        raise SystemExit(1)
    finally:
        default_signals()
    return exit_status(returncode)


def stop_group(proc: subprocess.Popen, signum: int) -> bool:
    """Signal Devin's process group, then wait up to 2s for it to exit. True if still alive."""
    for target in (lambda: os.killpg(proc.pid, signum), lambda: os.kill(proc.pid, signum)):
        try:
            target()
        except OSError:
            pass
    tries = 0
    alive = proc.poll() is None
    while alive and tries < 40:
        time.sleep(0.05)
        tries += 1
        alive = proc.poll() is None
    return alive


# --------------------------------------------------------------------------- #
# Result classification
# --------------------------------------------------------------------------- #


def is_retryable(log_path: str) -> bool:
    try:
        text = Path(log_path).read_text(errors="replace")
        matches = list(RETRY_HEADER.finditer(text))
        try:
            # Repeated copies are allowed; trailing errors or hints still fail closed.
            detail = json.loads(text[matches[-1].end():]) if matches else {}
        except json.JSONDecodeError:
            detail = {}
        return (isinstance(detail, dict)
                and detail.get("cognition.ai/errorKind") == "internal"
                and detail.get("cognition.ai/retryable") is True)
    except Exception:
        return False


class _Invalid(Exception):
    pass


def terminal_response(export_path: str, output_path: str):
    """Write the terminal agent message of an ATIF-v1.7 export to OUT, or return why not."""
    try:
        try:
            document_value = json.loads(Path(export_path).read_text())
        except (OSError, json.JSONDecodeError) as exc:
            raise _Invalid(f"missing or malformed Devin ATIF export: {exc}")
        if document_value.get("schema_version") != "ATIF-v1.7":
            raise _Invalid(
                f"unsupported Devin ATIF schema: {document_value.get('schema_version')!r}")
        steps = document_value.get("steps")
        if not isinstance(steps, list) or not steps:
            raise _Invalid("Devin ATIF export has no steps")
        terminal = steps[-1]
        if not isinstance(terminal, dict) or terminal.get("source") != "agent":
            raise _Invalid("Devin ATIF export has no terminal agent response")
        if terminal.get("tool_calls") not in (None, []):
            raise _Invalid("Devin ATIF export ended on a pending or denied tool call")
        message = terminal.get("message")
        if not isinstance(message, str) or not message.strip():
            raise _Invalid("Devin ATIF terminal response is empty")
        Path(output_path).write_text(message.rstrip() + "\n")
    except _Invalid as exc:
        return f"{exc}\n"
    except Exception:
        return traceback.format_exc()
    return None


# --------------------------------------------------------------------------- #
# Usage
# --------------------------------------------------------------------------- #


def usage(src: str) -> dict:
    export = document(src)
    steps = [step for step in export.get("steps") or [] if isinstance(step, dict)]
    agent = [step for step in steps if step.get("source") == "agent"]
    metrics = export.get("final_metrics") or {}
    return dict(served=[step["model_name"] for step in agent if step.get("model_name")],
                prompt=metrics.get("total_prompt_tokens"), cached=metrics.get("total_cached_tokens"),
                cache_write=None, completion=metrics.get("total_completion_tokens"), reasoning=None,
                cost=metrics.get("total_cost_usd"), turns=len(agent) if export else None,
                source="devin ATIF final_metrics")
