"""plx-engine command line: flags, validation, defaults, dispatch, exit codes and help.

Parses the wrapper's flags exactly as the original shell implementation did
(order-sensitive `--help`/`--print-rubric`, `missing value` checks), validates
the engine/mode/full-access combinations, resolves paths and defaults, creates
the lane temp dir, runs one engine adapter, and on every exit path records the
usage of a launched lane and removes the temp dir through `plx-clean-temp`.

USAGE:
    from plx_engine.cli import main
    sys.exit(main(["--engine", "codex", "--mode", "ro", "--repo", "/abs/repo",
                   "--prompt-file", "brief.md", "--stdout"]))
"""

from __future__ import annotations

import os
from typing import List

from . import claude, codex, devin, gemini, grok
from .lane import (Interrupted, Lane, abspath, assemble_exec_prompt, clean_temp, emit,
                   init_signals, logical_dir, make_temp_dir, nonempty, read_bytes, say,
                   warn_served, write_usage)

# --------------------------------------------------------------------------- #
# Help text
# --------------------------------------------------------------------------- #

HELP = r"""plx-engine — run a coding engine headless against a repo (Parallax engine API)

Usage:
  plx-engine --engine codex|grok|claude|gemini --mode ro|rw --repo <abs-path> \
    --prompt-file <file> [--rubric <name>] [--model <m>] [--effort <e>] --stdout
  plx-engine --engine devin --mode full-access --repo <abs-path> \
    --prompt-file <file> [--rubric <name>] [--model <m>] --stdout
  plx-engine ... --out <file> --log <file>     (instead of --stdout)
  plx-engine --print-rubric <name>             (print prompts/<name>.md and exit)

What it does:
  One non-interactive engine turn. Mode `ro` cannot edit; `rw` confines edits to
  --repo unless an explicit full-access flag is given. Devin requires `full-access`.
  --rubric injects prompts/<name>.md ahead of the prompt file, which should open
  with the header the rubric expects. Only the engine's final message is emitted.

Flags:
  --engine <e>          codex | grok | claude | devin | gemini (required)
  --mode <m>            ro | rw for codex/grok/claude/gemini; full-access for Devin
  --repo <dir>          absolute path to the target repo (required)
  --prompt-file <file>  file containing the brief/spec (required)
  --rubric <name>       lane rubric to inject (a file name under prompts/, no .md)
  --build-writer-full-access
                        allow one rw build-worker-rubric Codex/Claude lane to write
                        Git metadata; invalid for ro, Grok, or other rubrics
  --claude-passthrough-full-access
                        give one rubric-free rw Claude passthrough full host access
  --codex-passthrough-full-access
                        give one rubric-free rw Codex passthrough full host access
  --model <m>           codex: default gpt-6.1-sol · claude: default claude-opus-5-5 ·
                        grok: default grok-4.6 · devin: default swe-2-high · gemini: auto
  --effort <e>          codex: default medium · claude: default high ·
                        grok-4.6: always medium · other Grok models: default medium
                        Gemini and Devin reject --effort; choose a model instead.
  --stdout              print the final message to stdout; temp files auto-cleaned
  --out <f> --log <f>   instead of --stdout: write final message / full log to files
  --usage <f>           write the lane usage record here (default with --out:
                        <name>.usage.json beside <name>.out.md, else <out>.usage.json)
  --print-rubric <n>    print the named rubric (e.g. reviewer-correctness)
  --help                this text

Caller notes:
  * Engine turns can run 10-40+ min; prefer a background shell with --out/--log.
  * Grok prints non-fatal AuthorizationRequired lines to stderr; trust the exit code.
  * Full-access flags change transport permission only, never task authority.
  * The usage record (JSON, written on failure and interruption too) holds the
    requested and served models, wall time, tokens (prompt_tokens counts all
    input incl. cache), and cost_usd with cost_source vendor|unknown. null means
    the engine did not report it. Codex and Gemini report no cost.
  * A served model that does not match --model prints a stderr warning; the
    lane still succeeds. Codex does not report its served model.
  * SIGTERM/SIGINT stop the engine process, record usage, and exit 143/130.

Exit codes:
  0  success — stdout (or --out) holds the engine's final message
  1  engine or wrapper failure — details on stderr / in the log
  2  usage error — bad flags or missing/empty inputs
  3  not signed in — tell the user to log in (codex login / grok login / claude /login / devin auth login)
  4  Devin explicitly retryable internal protocol failure — reconcile partial work before retry
  130/143  interrupted by SIGINT/SIGTERM — the engine process was stopped
"""

# --------------------------------------------------------------------------- #
# Engines and defaults
# --------------------------------------------------------------------------- #

ADAPTERS = {"codex": codex, "grok": grok, "claude": claude, "devin": devin, "gemini": gemini}

# engine -> (default model, default effort); "" means the engine takes no effort.
DEFAULTS = {
    "grok": ("grok-4.6", "medium"),
    "codex": ("gpt-6.1-sol", "medium"),
    "claude": ("claude-opus-5-5", "high"),
    "gemini": ("auto", ""),
    "devin": ("swe-2-high", ""),
}

VALUE_FLAGS = {
    "--engine": "engine", "--mode": "mode", "--repo": "repo", "--prompt-file": "prompt",
    "--rubric": "rubric", "--model": "model", "--effort": "effort", "--out": "out",
    "--log": "log", "--usage": "usage",
}
SWITCH_FLAGS = {
    "--stdout": "stdout",
    "--build-writer-full-access": "build_writer_full_access",
    "--claude-passthrough-full-access": "claude_passthrough_full_access",
    "--codex-passthrough-full-access": "codex_passthrough_full_access",
}


def usage_error(message: str) -> None:
    say(message)
    raise SystemExit(2)


# --------------------------------------------------------------------------- #
# Flag parsing
# --------------------------------------------------------------------------- #


def need_value(flag: str, value: str) -> None:
    if not value:
        usage_error(f"missing value for {flag}")


def parse_flags(lane: Lane, argv: List[str]) -> None:
    """Flags are handled in order: --help and --print-rubric act (and exit)
    as soon as they are reached, before any later flag is validated."""
    index = 0
    while index < len(argv):
        arg = argv[index]
        value = argv[index + 1] if index + 1 < len(argv) else ""
        if arg in VALUE_FLAGS:
            need_value(arg, value)
            setattr(lane, VALUE_FLAGS[arg], value)
            index += 2
        elif arg in SWITCH_FLAGS:
            setattr(lane, SWITCH_FLAGS[arg], True)
            index += 1
        elif arg == "--print-rubric":
            need_value(arg, value)
            print_rubric(lane, value)
        elif arg in ("--help", "-h"):
            emit(HELP.encode("utf-8"))
            raise SystemExit(0)
        else:
            usage_error(f"unknown arg: {arg} (see --help)")


def print_rubric(lane: Lane, name: str) -> None:
    path = f"{lane.prompts_dir}/{name}.md"
    if not os.path.isfile(path):
        usage_error(f"no such rubric: {name} (looked at {path})")
    try:
        with open(path, "rb") as handle:
            data = handle.read()
    except OSError as exc:
        say(f"cat: {path}: {exc.strerror}")
        raise SystemExit(1)
    emit(data)
    raise SystemExit(0)


# --------------------------------------------------------------------------- #
# Validation
# --------------------------------------------------------------------------- #


def validate(lane: Lane) -> None:
    """Exit 2 on the first violated rule, in the reference order."""
    if lane.engine not in ADAPTERS:
        usage_error("--engine must be codex|grok|claude|devin|gemini")
    if lane.mode not in ("ro", "rw", "full-access"):
        usage_error("--mode must be ro|rw|full-access")
    if lane.engine == "devin":
        if lane.mode != "full-access":
            usage_error("Devin requires --mode full-access; its transport is not read-only "
                        "or workspace-confined")
        if lane.effort:
            usage_error("Devin does not support --effort; choose an exact model variant "
                        "such as swe-2-medium, swe-2-high, or swe-2-max")
    elif lane.engine == "gemini" and lane.effort:
        usage_error("Gemini does not support --effort; use --model instead")
    elif lane.mode == "full-access":
        usage_error("--mode full-access supports only Devin")
    if lane.build_writer_full_access:
        if lane.mode != "rw":
            usage_error("--build-writer-full-access requires --mode rw")
        if lane.rubric != "build-worker":
            usage_error("--build-writer-full-access requires --rubric build-worker")
        if lane.engine not in ("codex", "claude"):
            usage_error("--build-writer-full-access supports only codex or claude")
    if lane.claude_passthrough_full_access:
        if not (lane.engine == "claude" and lane.mode == "rw" and not lane.rubric
                and not lane.build_writer_full_access):
            usage_error("--claude-passthrough-full-access requires rubric-free Claude --mode rw")
    if lane.codex_passthrough_full_access:
        if not (lane.engine == "codex" and lane.mode == "rw" and not lane.rubric
                and not lane.build_writer_full_access):
            usage_error("--codex-passthrough-full-access requires rubric-free Codex --mode rw")
    if not os.path.isdir(lane.repo):
        usage_error(f"repo not found: {lane.repo}")
    if not nonempty(lane.prompt):
        usage_error(f"prompt file missing/empty: {lane.prompt}")


# --------------------------------------------------------------------------- #
# Paths, defaults and lane setup
# --------------------------------------------------------------------------- #


def resolve(lane: Lane) -> None:
    # The claude engine runs with cwd = repo; caller-relative paths must be
    # absolutized before that.
    lane.repo = logical_dir(lane.repo)
    lane.prompt = abspath(lane.prompt)
    if lane.out:
        lane.out = abspath(lane.out)
    if lane.log:
        lane.log = abspath(lane.log)
    if lane.usage:
        lane.usage = abspath(lane.usage)
    if not lane.usage and lane.out and not lane.stdout:
        if lane.out.endswith(".out.md"):
            lane.usage = lane.out[:-len(".out.md")] + ".usage.json"
        else:
            lane.usage = lane.out + ".usage.json"

    model, effort = DEFAULTS[lane.engine]
    lane.model = lane.model or model
    if effort:
        lane.effort = lane.effort or effort
    # Grok 4.6 is tuned and validated only at medium reasoning in Parallax. Keep
    # this invariant at the execution boundary so every pipeline and passthrough
    # gets the same setting, including callers that request another effort.
    if lane.model == "grok-4.6":
        lane.effort = "medium"

    if lane.rubric:
        lane.rubric_file = f"{lane.prompts_dir}/{lane.rubric}.md"
        if not nonempty(lane.rubric_file):
            usage_error(f"no such rubric: {lane.rubric} (looked at {lane.rubric_file})")


def prepare(lane: Lane) -> None:
    """Temp dir first, so every later exit (usage errors included) cleans it."""
    lane.tmp_dir = make_temp_dir()
    if lane.stdout:
        lane.out = lane.tmp("output.md")
        lane.log = lane.tmp("engine.log")
    else:
        if not lane.out:
            usage_error("--out required (or use --stdout)")
        if not lane.log:
            usage_error("--log required (or use --stdout)")
    os.makedirs(os.path.dirname(lane.out), exist_ok=True)
    os.makedirs(os.path.dirname(lane.log), exist_ok=True)
    if lane.usage:
        os.makedirs(os.path.dirname(lane.usage), exist_ok=True)
    assemble_exec_prompt(lane)


# --------------------------------------------------------------------------- #
# Run
# --------------------------------------------------------------------------- #


def run(lane: Lane, argv: List[str]) -> None:
    parse_flags(lane, argv)
    validate(lane)
    resolve(lane)
    prepare(lane)
    adapter = ADAPTERS[lane.engine]
    adapter.run(lane)
    warn_served(lane, adapter.usage)
    if lane.stdout:
        emit(read_bytes(lane.out))
    else:
        emit(f"OK plx-engine engine={lane.engine} mode={lane.mode} out={lane.out} "
             f"log={lane.log}\n".encode("utf-8", "surrogateescape"))


def exit_code(code) -> int:
    if code is None:
        return 0
    if isinstance(code, int):
        return code
    say(str(code))
    return 1


# --------------------------------------------------------------------------- #
# Entry point
# --------------------------------------------------------------------------- #


def main(argv: List[str]) -> int:
    bin_dir = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
    lane = Lane(bin_dir=bin_dir)
    init_signals()
    try:
        run(lane, argv)
        rc = 0
    except SystemExit as exc:
        rc = exit_code(exc.code)
    except Interrupted as stop:
        rc = 128 + stop.signum
    except BrokenPipeError:
        rc = 1
    except Exception as exc:  # wrapper failure: report it like a failed shell step
        say(f"plx-engine: {exc}")
        rc = 1
    # Exit path: record usage for a launched lane, then remove the temp dir.
    if lane.engine in ADAPTERS:
        write_usage(lane, ADAPTERS[lane.engine].usage, rc)
    clean_temp(lane)
    return rc
