"""Claude adapter: one `claude -p` stream-json turn in safe mode with a pinned sandbox.

The rubric goes in as an appended system prompt; the brief plus a Parallax
runtime boundary (guidance list and mode rules) goes in on stdin. Exit 0 alone is
not success: the terminal result event must not report an error.

USAGE:
    from plx_engine import claude
    claude.run(lane)                   # raises SystemExit(1|3) on failure
    claude.usage(stream_path)          # normalized usage fields from the stream
"""

from __future__ import annotations

import os
import traceback
from pathlib import Path
from typing import Optional

from .lane import (Lane, add, append, emit_stderr, encode, events, grep, list_guidance,
                   matches, nonempty, read_bytes, run_owned, say, show_head, tally, truncate,
                   write_boundary_prompt)

# --------------------------------------------------------------------------- #
# Settings, flags and prompt text
# --------------------------------------------------------------------------- #

TOOLS = "Read,Grep,Glob,Bash"
AUTH_PATTERN = "not logged in|please run /login"

SAFE_MODE_INTRO = (
    "Safe mode disables automatic project customization. Before inspecting or changing a "
    "path, read the listed guidance that governs it. Root files apply repo-wide; nested "
    "files and .claude/rules apply only to their subtree or declared paths.")
BUILD_WRITER_OUTRO = (
    "Full host access is enabled only so this standalone Build worker can write repository "
    "Git metadata and launch its packaged review lanes. It does not expand task authority: "
    "work only inside this repository, follow the accepted spec and repository guidance, "
    "and do not publish or mutate external systems unless the spec explicitly authorizes "
    "the exact action and target. Direct Edit and Write tools are unavailable.")
PASSTHROUGH_OUTRO = (
    "Full host access is available for this explicit Claude passthrough. Use it only as "
    "needed for the user request. Follow repository guidance. Do not publish or change "
    "remote systems unless the request authorizes the action and target.")
RW_OUTRO = ("For mutations, use sandboxed Bash commands confined to the repository. Direct "
            "Edit and Write tools are unavailable.")
RO_OUTRO = ("Read-only: use Bash only to inspect (git, diff, search, read-only scripts). The "
            "sandbox blocks writes to the repository; use $TMPDIR for scratch files.")


def settings(lane: Lane) -> str:
    full_access = lane.build_writer_full_access or lane.claude_passthrough_full_access
    if full_access:
        return '{"sandbox":{"enabled":false}}'
    filesystem = ""
    if lane.mode == "ro":
        # ro Bash may inspect but never write the checkout; the OS sandbox enforces it.
        repo_json = lane.repo.replace("\\", "\\\\").replace('"', '\\"')
        filesystem = ',"filesystem":{"denyWrite":["' + repo_json + '"]}'
    return ('{"sandbox":{"enabled":true,"failIfUnavailable":true,'
            '"autoAllowBashIfSandboxed":true,"allowUnsandboxedCommands":false,'
            '"network":{"allowedDomains":[],"strictAllowlist":true}' + filesystem + '}}')


def flags(lane: Lane) -> list:
    # Dynamic sections (cwd, git status, memory paths) leave the system prompt so
    # parallel lanes share one cached prefix. stream-json makes the log a full
    # transcript whose terminal result event carries is_error, usage and cost.
    flags = ["--model", lane.model, "--effort", lane.effort, "--no-session-persistence",
             "--exclude-dynamic-system-prompt-sections", "--output-format", "stream-json",
             "--verbose", "--settings", settings(lane)]
    if lane.claude_passthrough_full_access:
        flags += ["--dangerously-skip-permissions"]
    else:
        flags += ["--safe-mode", "--strict-mcp-config", "--mcp-config", '{"mcpServers":{}}']
    if lane.build_writer_full_access:
        flags += ["--dangerously-skip-permissions", "--tools", TOOLS, "--allowedTools", TOOLS]
    elif not lane.claude_passthrough_full_access:
        if lane.mode == "ro":
            flags += ["--permission-mode", "dontAsk", "--tools", TOOLS, "--allowedTools", TOOLS]
        else:
            flags += ["--permission-mode", "acceptEdits", "--tools", TOOLS,
                      "--allowedTools", TOOLS]
    if lane.rubric_file:
        flags += ["--append-system-prompt-file", lane.rubric_file]
    return flags


def outro(lane: Lane) -> str:
    if lane.build_writer_full_access:
        return BUILD_WRITER_OUTRO
    if lane.claude_passthrough_full_access:
        return PASSTHROUGH_OUTRO
    return RW_OUTRO if lane.mode == "rw" else RO_OUTRO


# --------------------------------------------------------------------------- #
# Transport
# --------------------------------------------------------------------------- #


def run(lane: Lane) -> None:
    prompt = lane.tmp("claude-prompt.md")
    argv = ["claude", "-p"] + flags(lane)
    intro = None if lane.claude_passthrough_full_access else SAFE_MODE_INTRO
    write_boundary_prompt(lane, prompt, intro, list_guidance(lane.repo), outro(lane))

    stream = lane.tmp("claude-stream.jsonl")
    lane.begin(stream)
    truncate(lane.out)
    with open(prompt, "rb") as stdin, open(stream, "wb") as out, open(lane.log, "wb") as log:
        claude_rc = run_owned(lane.engine, argv, stdin=stdin, stdout=out, stderr=log,
                              cwd=lane.repo)
    remove_write_staging(lane.repo)
    error = result_to_out(stream, lane.out)
    if nonempty(stream):
        append(lane.log, b"\n--- claude stream-json ---\n" + read_bytes(stream))

    failed = claude_rc != 0 or error is not None
    if failed and (grep(AUTH_PATTERN, lane.log) or
                   (error is not None and matches(AUTH_PATTERN, error))):
        # Codex's macOS sandbox hides the keychain that holds Claude's login, so a
        # Claude lane launched from a sandboxed Codex host always looks logged out.
        codex_sandbox = os.environ.get("CODEX_SANDBOX", "")
        if codex_sandbox:
            say("plx-engine: Claude login is unreachable from inside the Codex sandbox "
                f"(CODEX_SANDBOX={codex_sandbox}), not missing — rerun this wrapper call with "
                "host approval or outside the sandbox. Headless Codex runs with approvals off "
                "cannot do this.")
            raise SystemExit(3)
        say("plx-engine: Claude credentials unavailable — if Claude works in a local terminal, "
            "retry this wrapper with narrowly scoped host approval; otherwise run "
            "`claude /login`.")
        raise SystemExit(3)
    if failed:
        truncate(lane.out)
        say(f"claude invocation failed (exit {claude_rc})")
        if error:
            emit_stderr(encode(error))
        show_head(lane.log, 40)
        raise SystemExit(1)


def remove_write_staging(repo: str) -> None:
    """Claude Code can leave an empty write-staging directory in the checkout.
    Only empty directories are removed, and never through a symlinked .claude."""
    if os.path.islink(repo + "/.claude"):
        return
    try:
        os.rmdir(repo + "/.claude/.cc-writes")
    except OSError:
        return
    try:
        os.rmdir(repo + "/.claude")
    except OSError:
        pass


# --------------------------------------------------------------------------- #
# Result and usage
# --------------------------------------------------------------------------- #


def result_to_out(stream: str, out: str) -> Optional[str]:
    """Write the final text of a stream-json run to OUT; return the failure text instead."""
    try:
        result = None
        for event in events(stream):
            if event.get("type") == "result":
                result = event
        if result is None:
            return "claude stream has no result event\n"
        text = result.get("result") or ""
        if result.get("is_error") or result.get("subtype") not in (None, "success"):
            return f"claude result is an error (subtype {result.get('subtype')}): {text}\n"
        if not text.strip():
            return "claude produced an empty result\n"
        Path(out).write_text(text.rstrip("\n") + "\n")
    except Exception:
        return traceback.format_exc()
    return None


def usage(src: str) -> dict:
    result, served, messages = None, [], {}
    for event in events(src):
        kind = event.get("type")
        if kind == "assistant":
            message = event.get("message") or {}
            if message.get("model"):
                served.append(message["model"])
            if message.get("id") and message.get("usage"):
                messages[message["id"]] = message["usage"]
        elif kind == "result":
            result = event
    if result and result.get("modelUsage"):
        # modelUsage covers every model the run called and is what the cost sums.
        rows = tally(result["modelUsage"].values(),
                     ("inputTokens", "cacheReadInputTokens", "cacheCreationInputTokens",
                      "outputTokens", "thinkingTokens"))
        fresh, read = rows["inputTokens"], rows["cacheReadInputTokens"]
        write = rows["cacheCreationInputTokens"]
        out, thinking = rows["outputTokens"], rows["thinkingTokens"]
    else:
        # Stopped before the result event: a message split over events repeats its usage.
        rows = tally(messages.values(),
                     ("input_tokens", "cache_read_input_tokens", "cache_creation_input_tokens",
                      "output_tokens"))
        fresh, read = rows["input_tokens"], rows["cache_read_input_tokens"]
        write = rows["cache_creation_input_tokens"]
        out, thinking = rows["output_tokens"], None
    # Anthropic input_tokens are the uncached part only.
    return dict(served=served,
                prompt=add(fresh, read or 0, write or 0) if fresh is not None else None,
                cached=read, cache_write=write, completion=out, reasoning=thinking,
                cost=(result or {}).get("total_cost_usd"), turns=(result or {}).get("num_turns"),
                source="claude stream-json" if result else "claude stream-json (no result event)")
