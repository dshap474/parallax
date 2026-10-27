"""Codex adapter: one `codex exec` turn with a pinned sandbox, JSONL log and usage parser.

Isolated lanes ignore the user's Codex config and bundled skills; the sandbox is
read-only for `ro`, workspace-write for `rw`, and full access only for the
explicit Build writer or Codex passthrough. Never the approvals-and-sandbox bypass.

USAGE:
    from plx_engine import codex
    codex.run(lane)            # raises SystemExit(1|3) on failure
    codex.usage(lane.log)      # normalized usage fields from the JSONL log
"""

from __future__ import annotations

import subprocess

from .lane import Lane, events, grep, nonempty, run_owned, say, show_head

# --------------------------------------------------------------------------- #
# Transport
# --------------------------------------------------------------------------- #

AUTH_PATTERN = "not logged in|401 unauthorized|codex login|invalid api key"


def run(lane: Lane) -> None:
    if lane.build_writer_full_access or lane.codex_passthrough_full_access:
        sandbox = "danger-full-access"
    elif lane.mode == "ro":
        sandbox = "read-only"
    else:
        sandbox = "workspace-write"
    # --json makes the log a JSONL event stream; usage rides on turn.completed.
    flags = ["--json", "--sandbox", sandbox, "-c", "approval_policy=never",
             "--skip-git-repo-check", "-C", lane.repo, "-m", lane.model,
             "-c", f"model_reasoning_effort={lane.effort}", "--ephemeral", "-o", lane.out, "-"]
    if not lane.codex_passthrough_full_access:
        # Isolated lanes also skip the bundled skill list (~4.5 KB per request).
        flags = ["--ignore-user-config", "-c", "skills.bundled.enabled=false"] + flags

    lane.begin(lane.log)
    with open(lane.exec_prompt, "rb") as stdin, open(lane.log, "wb") as log:
        rc = run_owned(lane.engine, ["codex", "exec"] + flags, stdin=stdin, stdout=log,
                       stderr=subprocess.STDOUT)
    if rc != 0:
        if grep(AUTH_PATTERN, lane.log):
            say("plx-engine: codex not authenticated — run `codex login` "
                "(or set CODEX_API_KEY), then retry.")
            raise SystemExit(3)
        say("codex invocation failed")
        show_head(lane.log, 40)
        raise SystemExit(1)
    if not nonempty(lane.out):
        say(f"codex produced empty output: {lane.out}")
        raise SystemExit(1)


# --------------------------------------------------------------------------- #
# Usage
# --------------------------------------------------------------------------- #


def usage(src: str) -> dict:
    usage_event, turns = {}, 0
    for event in events(src):
        if event.get("type") == "turn.completed" and event.get("usage"):
            usage_event = event["usage"]
        elif (event.get("type") == "item.completed"
              and (event.get("item") or {}).get("type") == "command_execution"):
            turns += 1
    # Codex input_tokens already include the cached subset; it reports no served model or cost.
    return dict(served=[], prompt=usage_event.get("input_tokens"),
                cached=usage_event.get("cached_input_tokens"),
                cache_write=usage_event.get("cache_write_input_tokens"),
                completion=usage_event.get("output_tokens"),
                reasoning=usage_event.get("reasoning_output_tokens"), cost=None,
                turns=turns if usage_event else None,
                source="codex turn.completed" if usage_event else "codex (no turn.completed event)")
