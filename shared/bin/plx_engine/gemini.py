"""Gemini adapter: one sandboxed `gemini` JSON turn on macOS Seatbelt with pinned system settings.

System settings override user/project customization without replacing auth:
read tools in `ro`, file-edit tools added in `rw`; shell, extensions, MCP, hooks,
agents, telemetry and auto-update disabled. Inherited extra workspace roots are
rejected because Gemini concatenates them across settings files.

USAGE:
    from plx_engine import gemini
    gemini.run(lane)              # raises SystemExit(1|3) on failure
    gemini.usage(raw_json_path)   # normalized usage fields from the JSON stats
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import traceback
from pathlib import Path

from .lane import (Lane, append, document, emit_stderr, encode, grep, read_bytes, run_owned,
                   say, show_tail, tally, truncate)

# --------------------------------------------------------------------------- #
# Settings and patterns
# --------------------------------------------------------------------------- #

UNSET_ENV = ("SANDBOX", "SANDBOX_FLAGS", "SANDBOX_MOUNTS", "SANDBOX_ENV", "BUILD_SANDBOX",
             "GEMINI_SANDBOX_PROXY_COMMAND", "GEMINI_SYSTEM_MD")
AUTH_PATTERN = ("Please set an Auth method|Please set.*GEMINI_API_KEY|not authenticated|"
                "invalid API key|API key not valid|authentication required|"
                "ProjectIdRequiredError|Error authenticating")


class _Rejected(Exception):
    pass


def write_settings(settings: str, mode: str, repo: str) -> None:
    """Reject inherited extra workspace roots, then write the system settings file."""
    for source in [Path.home() / ".gemini/settings.json", Path(repo) / ".gemini/settings.json"]:
        if source.exists():
            try:
                existing = json.loads(source.read_text())
            except (ValueError, OSError):
                raise _Rejected(f"plx-engine: cannot validate Gemini workspace roots in {source}; "
                                "plain JSON settings required")
            if (existing.get("includeDirectories")
                    or (existing.get("context") or {}).get("includeDirectories")):
                raise _Rejected(f"plx-engine: Gemini extra includeDirectories are unsupported: {source}")
    core = ["read_file", "read_many_files", "list_directory", "glob", "search_file_content"]
    if mode == "rw":
        core += ["replace", "write_file"]
    Path(settings).write_text(json.dumps({
        "tools": {"core": core, "allowed": [], "sandbox": True,
                  "discoveryCommand": "", "callCommand": "", "enableHooks": False},
        "context": {"includeDirectories": []}, "mcpServers": {},
        "mcp": {"serverCommand": "", "allowed": ["plx-disabled-" + Path(settings).parent.name]},
        "skills": {"enabled": False}, "hooksConfig": {"enabled": False},
        "admin": {"mcp": {"enabled": False}, "extensions": {"enabled": False}},
        "experimental": {"enableAgents": False},
        "general": {"enableAutoUpdate": False},
        "telemetry": {"enabled": False}, "privacy": {"usageStatisticsEnabled": False}
    }))


def os_name() -> str:
    """`uname -s` as a subprocess (not os.uname) so PATH decides, as in the shell."""
    try:
        result = subprocess.run(["uname", "-s"], stdout=subprocess.PIPE)
    except OSError:
        return ""
    return result.stdout.decode("utf-8", "surrogateescape").rstrip("\n")


# --------------------------------------------------------------------------- #
# Transport
# --------------------------------------------------------------------------- #


def run(lane: Lane) -> None:
    truncate(lane.out)
    if shutil.which("gemini") is None:
        say("plx-engine: Gemini CLI not found; install @google/gemini-cli and authenticate "
            "with gemini")
        raise SystemExit(1)
    settings = lane.tmp("gemini-settings.json")
    raw = lane.tmp("gemini-response.json")
    approval = "auto_edit" if lane.mode == "rw" else "default"
    if os_name() == "Darwin":
        sandbox = "sandbox-exec"
    else:
        say("plx-engine: Gemini transport currently requires macOS Seatbelt")
        raise SystemExit(1)
    try:
        write_settings(settings, lane.mode, lane.repo)
    except _Rejected as exc:
        say(str(exc))
        raise SystemExit(1)
    except Exception:
        emit_stderr(encode(traceback.format_exc()))
        raise SystemExit(1)

    env = {key: value for key, value in os.environ.items() if key not in UNSET_ENV}
    env.update(GEMINI_CLI_SYSTEM_SETTINGS_PATH=settings, GEMINI_CLI_SYSTEM_DEFAULTS_PATH=settings,
               GEMINI_SANDBOX=sandbox, SEATBELT_PROFILE="permissive-open")
    argv = ["gemini", "--sandbox", "--extensions", "none", "--approval-mode", approval,
            "--model", lane.model, "--output-format", "json"]
    lane.begin(raw)
    with open(lane.exec_prompt, "rb") as stdin, open(raw, "wb") as out, \
            open(lane.log, "wb") as log:
        rc = run_owned(lane.engine, argv, stdin=stdin, stdout=out, stderr=log, cwd=lane.repo,
                       env=env)
    append(lane.log, read_bytes(raw))
    if rc != 0:
        if grep(AUTH_PATTERN, lane.log):
            say("plx-engine: Gemini authentication unavailable; run gemini to sign in or "
                "configure GEMINI_API_KEY")
            show_tail(lane.log, 20)
            raise SystemExit(3)
        say(f"plx-engine: Gemini invocation failed (exit {rc}); see log: {lane.log}")
        show_tail(lane.log, 20)
        raise SystemExit(1)
    if not write_response(raw, lane.out):
        raise SystemExit(1)


def write_response(raw: str, out: str) -> bool:
    try:
        data = json.loads(Path(raw).read_text())
        if not isinstance(data, dict) or data.get("error"):
            raise ValueError("Gemini returned an error envelope")
        response = data.get("response")
        if not isinstance(response, str) or not response.strip():
            raise ValueError("Gemini returned no final response")
        Path(out).write_text(response.rstrip() + "\n")
    except (ValueError, OSError) as error:
        say(f"plx-engine: invalid Gemini response: {error}")
        return False
    except Exception:
        emit_stderr(encode(traceback.format_exc()))
        return False
    return True


# --------------------------------------------------------------------------- #
# Usage
# --------------------------------------------------------------------------- #


def usage(src: str) -> dict:
    models = (document(src).get("stats") or {}).get("models") or {}
    rows = tally([(value or {}).get("tokens") or {} for value in models.values()],
                 ("prompt", "cached", "candidates", "thoughts"))
    return dict(served=list(models), prompt=rows["prompt"], cached=rows["cached"],
                cache_write=None, completion=rows["candidates"], reasoning=rows["thoughts"],
                cost=None, turns=None, source="gemini json stats")
