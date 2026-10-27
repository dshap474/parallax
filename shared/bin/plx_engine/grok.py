"""Grok adapter: one headless `grok` turn with customization imports off and a pinned sandbox.

Grok imports Claude, Cursor and Codex customizations unless each import is
switched off; repository guidance those imports would carry is listed in the
prompt instead. The final answer comes from the session store (the envelope text
can merge pre-tool narration), and a successful run's session dir is removed.

USAGE:
    from plx_engine import grok
    grok.run(lane)             # raises SystemExit(1|3) on failure
    grok.usage(raw_json_path)  # normalized usage fields from the JSON envelope
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import traceback
import urllib.parse

from .lane import (Lane, add, append, document, emit_stderr, encode, grep, list_guidance,
                   nonempty, run_owned, say, show_head, write_boundary_prompt)

# --------------------------------------------------------------------------- #
# Isolation and prompt text
# --------------------------------------------------------------------------- #

ISOLATION = {f"GROK_{vendor}_{cell}_ENABLED": "0"
             for vendor in ("CLAUDE", "CURSOR", "CODEX")
             for cell in ("SKILLS", "RULES", "AGENTS", "MCPS", "HOOKS", "SESSIONS")}

BOUNDARY_INTRO = (
    "Claude, Cursor and Codex customization imports are disabled. Before inspecting or "
    "changing a path, read the listed guidance that governs it. Root files apply repo-wide; "
    "nested files and rule files apply only to their subtree or declared paths.")

# Genuine "not signed in" prints the OAuth sign-in prompt to stderr. This is the
# real login signal — NOT the AuthorizationRequired worker noise, which also
# appears on success.
AUTH_PATTERN = "Open this URL to sign in|Signing in with Grok"
SANDBOX_PATTERN = (
    "(seatbelt.*(fail|denied|operation not permitted)|(fail|denied|operation not permitted)"
    ".*seatbelt|sandbox(_init| initialization| setup).*(fail|denied|operation not permitted)"
    "|(fail|denied|operation not permitted).*(sandbox_init|sandbox initialization|sandbox setup))")


# --------------------------------------------------------------------------- #
# Transport
# --------------------------------------------------------------------------- #


def run(lane: Lane) -> None:
    sandbox = "read-only" if lane.mode == "ro" else "workspace"
    raw = lane.tmp("raw.json")
    prompt = lane.tmp("grok-prompt.md")
    write_boundary_prompt(lane, prompt, BOUNDARY_INTRO, list_guidance(lane.repo), None)

    argv = ["grok", "--no-auto-update", "--cwd", lane.repo,
            "--model", lane.model, "--effort", lane.effort,
            "--permission-mode", "bypassPermissions", "--sandbox", sandbox,
            "--no-plan", "--no-subagents", "--no-memory", "--no-alt-screen",
            "--output-format", "json", "--prompt-file", prompt]
    lane.begin(raw)
    with open(raw, "wb") as out, open(lane.log, "wb") as log:
        rc = run_owned(lane.engine, argv, stdin=subprocess.DEVNULL, stdout=out, stderr=log,
                       env=dict(os.environ, **ISOLATION))

    if grep(AUTH_PATTERN, lane.log):
        say("plx-engine: grok not authenticated — run `grok login` (or export XAI_API_KEY), "
            "then retry.")
        raise SystemExit(3)
    if rc != 0:
        if grep(SANDBOX_PATTERN, lane.log):
            say("PLX_GROK_SANDBOX_UNAVAILABLE")
            say(f"Grok {sandbox} sandbox could not initialize under the host sandbox.")
            say("The Grok lane did not start. Do not perform or attribute the task to this lane.")
            show_head(lane.log, 40)
            raise SystemExit(1)
        say(f"grok invocation failed (exit {rc})")
        show_head(lane.log, 40)
        raise SystemExit(1)

    stop = stop_reason(raw)
    if stop in ("cancelled", "Cancelled"):
        say("plx-engine: grok turn was cancelled — a tool call was gated, not auto-approved.")
        raise SystemExit(1)
    write_final_text(raw, lane.repo, lane.out)
    if not nonempty(lane.out):
        say(f"plx-engine: grok empty output (stopReason={stop})")
        raise SystemExit(1)
    append(lane.out, b"\n")
    remove_session(raw, lane.repo)


def stop_reason(raw: str) -> str:
    try:
        with open(raw) as handle:
            value = json.load(handle).get("stopReason") or ""
    except Exception:
        return ""
    # Printed then captured by the shell: str() form, trailing newlines dropped.
    return str(value).rstrip("\n")


def session_dir(repo: str, sid: str) -> str:
    return os.path.join(os.path.expanduser("~/.grok/sessions"),
                        urllib.parse.quote(os.path.realpath(repo), safe=""), sid)


def write_final_text(raw: str, repo: str, out: str) -> None:
    """The session store's last assistant message is the final answer; fall back to
    the envelope text, or the raw output when it is not JSON."""
    with open(out, "w") as target:
        try:
            try:
                with open(raw) as handle:
                    envelope = json.load(handle)
            except Exception:
                with open(raw) as handle:
                    target.write(handle.read())
                return
            text = envelope.get("text") or ""
            sid = envelope.get("sessionId") or ""
            history = os.path.join(session_dir(repo, sid), "chat_history.jsonl")
            try:
                if sid and "/" not in sid and sid not in (".", ".."):
                    with open(history, errors="replace") as lines:
                        for line in lines:
                            message = json.loads(line) if line.strip() else {}
                            content = message.get("content") if message.get("type") == "assistant" else None
                            if isinstance(content, str) and content.strip():
                                text = content
            except (OSError, ValueError, AttributeError):
                pass
            target.write(text)
        except Exception:
            emit_stderr(encode(traceback.format_exc()))
            raise SystemExit(1)


def remove_session(raw: str, repo: str) -> None:
    """Headless one-shot runs never resume; drop this run's session dir so
    ~/.grok/sessions doesn't grow without bound (grok has no --ephemeral).
    Failure paths exit earlier and keep the session for debugging."""
    try:
        with open(raw) as handle:
            sid = json.load(handle).get("sessionId") or ""
        if not sid:
            return
        directory = session_dir(repo, sid)
        if os.path.isdir(directory):
            shutil.rmtree(directory)
            parent = os.path.dirname(directory)
            if os.listdir(parent) in ([], ["prompt_history.jsonl"]):
                shutil.rmtree(parent)
    except Exception:
        pass


# --------------------------------------------------------------------------- #
# Usage
# --------------------------------------------------------------------------- #


def usage(src: str) -> dict:
    envelope = document(src)
    tokens = envelope.get("usage") or {}
    fresh, read = tokens.get("input_tokens"), tokens.get("cache_read_input_tokens")
    write = tokens.get("cache_creation_input_tokens")
    return dict(served=list(envelope.get("modelUsage") or {}),
                prompt=add(fresh, read or 0, write or 0) if fresh is not None else None,
                cached=read, cache_write=write, completion=tokens.get("output_tokens"),
                reasoning=tokens.get("reasoning_tokens"), cost=envelope.get("total_cost_usd"),
                turns=envelope.get("num_turns"), source="grok json envelope")
