"""Lane state, owned-child runner, prompt assembly and the usage record shared by every engine adapter.

A lane is one headless engine turn: the resolved flags, its output files, the
temp dir, the running child process, and the <lane>.usage.json written for it.
Adapters (codex.py, claude.py, ...) own everything engine-specific; this module
owns only what is identical across engines. Stdlib only, Python 3.9+ (the
wrapper runs under whatever `python3` is first on PATH).

USAGE:
    from .lane import Lane, run_owned, say
    lane.begin("/tmp/.../engine.log")
    with open(lane.exec_prompt, "rb") as stdin, open(lane.log, "wb") as log:
        rc = run_owned(lane.engine, ["codex", "exec", ...], stdin=stdin, stdout=log,
                       stderr=subprocess.STDOUT)
"""

from __future__ import annotations

import json
import os
import re
import secrets
import signal
import string
import subprocess
import sys
import time
from dataclasses import dataclass
from fnmatch import fnmatchcase
from pathlib import Path
from typing import Callable, Dict, Iterator, List, Optional

# --------------------------------------------------------------------------- #
# Output helpers
# --------------------------------------------------------------------------- #

# Paths arrive as surrogate-escaped str; encoding them back this way reproduces
# the raw bytes the shell version printed.


def encode(text: str) -> bytes:
    return text.encode("utf-8", "surrogateescape")


def _write(stream, data: bytes) -> None:
    stream.flush()
    stream.buffer.write(data)
    stream.buffer.flush()


def say(text: str) -> None:
    """One diagnostic line on stderr (bash `echo ... >&2`)."""
    _write(sys.stderr, encode(text + "\n"))


def emit(data: bytes) -> None:
    """Raw bytes on stdout (bash `cat`)."""
    _write(sys.stdout, data)


def emit_stderr(data: bytes) -> None:
    _write(sys.stderr, data)


def read_bytes(path: str) -> bytes:
    try:
        with open(path, "rb") as handle:
            return handle.read()
    except OSError:
        return b""


def nonempty(path: str) -> bool:
    """bash `[[ -s path ]]`."""
    try:
        return os.stat(path).st_size > 0
    except OSError:
        return False


def _lines(data: bytes) -> List[bytes]:
    parts = data.split(b"\n")
    lines = [part + b"\n" for part in parts[:-1]]
    if parts[-1]:
        lines.append(parts[-1])
    return lines


def head(data: bytes, count: int) -> bytes:
    """The first <count> lines of data (bash `sed -n '1,<count>p'`)."""
    return b"".join(_lines(data)[:count])


def show_head(path: str, count: int) -> None:
    """bash `[[ -s f ]] && sed -n '1,<count>p' f >&2`."""
    if nonempty(path):
        emit_stderr(head(read_bytes(path), count))


def show_tail(path: str, count: int) -> None:
    """bash `tail -<count> f >&2`."""
    emit_stderr(b"".join(_lines(read_bytes(path))[-count:]))


def matches(pattern: str, text: str) -> bool:
    """bash `grep -qiE pattern`: true when any line matches, case-insensitively."""
    return any(re.search(pattern, line, re.IGNORECASE) for line in text.split("\n"))


def grep(pattern: str, *paths: str) -> bool:
    """bash `grep -qiE pattern paths...` over files; unreadable files never match."""
    return any(matches(pattern, read_bytes(path).decode("utf-8", "replace")) for path in paths)


def append(path: str, data: bytes) -> None:
    with open(path, "ab") as handle:
        handle.write(data)


def truncate(path: str) -> None:
    """bash `: > path`."""
    with open(path, "wb"):
        pass


# --------------------------------------------------------------------------- #
# Lane
# --------------------------------------------------------------------------- #


@dataclass
class Lane:
    bin_dir: str
    engine: str = ""
    mode: str = ""
    repo: str = ""
    prompt: str = ""
    rubric: str = ""
    model: str = ""
    effort: str = ""
    out: str = ""
    log: str = ""
    usage: str = ""
    stdout: bool = False
    build_writer_full_access: bool = False
    claude_passthrough_full_access: bool = False
    codex_passthrough_full_access: bool = False
    rubric_file: str = ""
    exec_prompt: str = ""
    tmp_dir: str = ""
    usage_src: str = ""
    start_ts: Optional[int] = None

    @property
    def prompts_dir(self) -> str:
        return self.bin_dir + "/../prompts"

    def tmp(self, name: str) -> str:
        return self.tmp_dir + "/" + name

    def begin(self, usage_src: str) -> None:
        """Mark the launch: from here on the exit path records usage."""
        self.usage_src = usage_src
        self.start_ts = int(time.time())


# --------------------------------------------------------------------------- #
# Paths and temp dir
# --------------------------------------------------------------------------- #


def logical_cwd() -> str:
    """The shell's $PWD: the logical working directory, symlinks kept."""
    pwd = os.environ.get("PWD", "")
    try:
        if pwd.startswith("/") and os.path.samefile(pwd, "."):
            return pwd
    except OSError:
        pass
    return os.getcwd()


def abspath(path: str) -> str:
    """bash `case $1 in /*) ;; *) $PWD/$1`: absolutize without normalizing."""
    return path if path.startswith("/") else logical_cwd() + "/" + path


def logical_dir(path: str) -> str:
    """bash `cd "$dir" && pwd`: lexically canonical, symlinks kept."""
    return os.path.normpath(abspath(path))


def make_temp_dir() -> str:
    """mktemp -d "${TMPDIR:-/tmp}/plx-engine.XXXXXX", same name shape and mode."""
    base = os.environ.get("TMPDIR") or "/tmp"
    alphabet = string.ascii_letters + string.digits
    for _ in range(1000):
        path = base + "/plx-engine." + "".join(secrets.choice(alphabet) for _ in range(6))
        try:
            os.mkdir(path, 0o700)
            return path
        except FileExistsError:
            continue
        except OSError as exc:
            say(f"mktemp: mkdtemp failed on {base}/plx-engine.XXXXXX: {exc.strerror}")
            raise SystemExit(1)
    say(f"mktemp: mkdtemp failed on {base}/plx-engine.XXXXXX: File exists")
    raise SystemExit(1)


def clean_temp(lane: Lane) -> None:
    """Remove the lane temp dir through the confined helper, never recursively here."""
    if lane.tmp_dir:
        try:
            subprocess.call([lane.bin_dir + "/plx-clean-temp", lane.tmp_dir])
        except OSError:
            pass


# --------------------------------------------------------------------------- #
# Prompt assembly
# --------------------------------------------------------------------------- #

GUIDANCE_PRUNE = ("*/node_modules", "*/.venv", "*/venv", "*/.cache", "*/__pycache__",
                  "*/.tox", "*/.nox")
GUIDANCE_NAMES = ("AGENTS.md", "CLAUDE.md", "CLAUDE.local.md")
GUIDANCE_PATHS = ("*/.claude/rules/*.md",)


def assemble_exec_prompt(lane: Lane) -> None:
    """codex/grok/devin/gemini take one prompt stream: rubric (if any) prepended to
    the brief. claude keeps them separate: rubric -> system prompt, brief -> user prompt."""
    lane.exec_prompt = lane.prompt
    if lane.rubric_file and lane.engine != "claude":
        lane.exec_prompt = lane.tmp("prompt.md")
        with open(lane.exec_prompt, "wb") as handle:
            handle.write(read_file(lane.rubric_file) + b"\n\n" + read_file(lane.prompt))


def read_file(path: str) -> bytes:
    with open(path, "rb") as handle:
        return handle.read()


def list_guidance(repo: str, *extra: str) -> bytes:
    """Safe-mode Claude, Grok and Devin do not discover repo guidance, so list it in
    the prompt. Port of a `find -prune ... | LC_ALL=C sort -u` walk: no symlinked
    directories are entered, `*` in path patterns also matches `/`, and only paths
    that are (or point to) regular files are listed, relative to the repo."""
    path_patterns = GUIDANCE_PATHS + extra
    git_dir = repo + "/.git"
    found = []

    def visit(path: str, name: str) -> None:
        if fnmatchcase(path, git_dir) or any(fnmatchcase(path, p) for p in GUIDANCE_PRUNE):
            return
        if name in GUIDANCE_NAMES or any(fnmatchcase(path, p) for p in path_patterns):
            found.append(path)
        if os.path.isdir(path) and not os.path.islink(path):
            try:
                entries = [entry.name for entry in os.scandir(path)]
            except OSError:
                return
            prefix = path if path.endswith("/") else path + "/"
            for child in entries:
                visit(prefix + child, child)

    visit(repo, os.path.basename(repo))
    lines = []
    for path in sorted(set(found), key=encode):
        if os.path.isfile(path):
            relative = path[len(repo) + 1:] if path.startswith(repo + "/") else path
            lines.append(b"- " + encode(relative) + b"\n")
    return b"".join(lines) if lines else b"- No repository guidance files found.\n"


def write_boundary_prompt(lane: Lane, target: str, intro: Optional[str], guidance: bytes,
                          outro: Optional[str]) -> None:
    """The exec prompt followed by a `## Parallax runtime boundary` section."""
    data = read_file(lane.exec_prompt) + b"\n\n## Parallax runtime boundary\n"
    if intro is not None:
        data += encode(intro + "\n")
    data += guidance
    if outro is not None:
        data += encode(outro + "\n")
    with open(target, "wb") as handle:
        handle.write(data)


# --------------------------------------------------------------------------- #
# Signals and owned children
# --------------------------------------------------------------------------- #

# Signals ignored when the wrapper started stay ignored (a shell cannot trap them
# either), e.g. SIGINT for a wrapper launched in the background by a script.
_IGNORED_AT_START = set()
_STOP_SIGNALS = (signal.SIGTERM, signal.SIGINT)


class Interrupted(BaseException):
    """Raised by the wait-time handler; BaseException so no `except Exception` eats it."""

    def __init__(self, signum: int):
        super().__init__(signum)
        self.signum = signum


def _exit_on_signal(signum, frame) -> None:
    # Outside an engine wait a stop signal ends the wrapper like an untrapped
    # signal ends the shell: the exit path still records usage and cleans up.
    raise SystemExit(128 + signum)


def _interrupt(signum, frame) -> None:
    raise Interrupted(signum)


def init_signals() -> None:
    for signum in _STOP_SIGNALS:
        if signal.getsignal(signum) == signal.SIG_IGN:
            _IGNORED_AT_START.add(signum)
    default_signals()


def default_signals() -> None:
    _set_handlers(_exit_on_signal)


def interrupt_signals() -> None:
    _set_handlers(_interrupt)


def _set_handlers(handler) -> None:
    for signum in _STOP_SIGNALS:
        if signum not in _IGNORED_AT_START:
            signal.signal(signum, handler)


def _child_setup() -> None:
    # Non-interactive bash starts background children with SIGINT and SIGQUIT
    # ignored, so a terminal ^C reaches the engine only as the wrapper's SIGTERM.
    signal.signal(signal.SIGINT, signal.SIG_IGN)
    signal.signal(signal.SIGQUIT, signal.SIG_IGN)


def exit_status(returncode: int) -> int:
    """Popen's -N (killed by signal N) as the shell reports it: 128+N."""
    return returncode if returncode >= 0 else 128 - returncode


def spawn(argv: List[str], *, stdin, stdout, stderr, cwd: Optional[str] = None,
          env: Optional[Dict[str, str]] = None, new_session: bool = False,
          background: bool = True):
    """Start argv as a child (`background` = a shell `&` job), or return the status
    the shell would report when it cannot be started (1 bad cwd, 127 not found,
    126 not runnable)."""
    err_handle = stdout if stderr is subprocess.STDOUT else stderr

    def report(message: str) -> None:
        if hasattr(err_handle, "write"):
            err_handle.write(encode(message + "\n"))
            err_handle.flush()

    if cwd is not None and not os.path.isdir(cwd):
        report(f"plx-engine: cd: {cwd}: No such file or directory")
        return 1
    try:
        return subprocess.Popen(argv, stdin=stdin, stdout=stdout, stderr=stderr, cwd=cwd,
                                env=env, preexec_fn=_child_setup if background else None,
                                start_new_session=new_session)
    except FileNotFoundError:
        report(f"plx-engine: {argv[0]}: command not found")
        return 127
    except OSError as exc:
        report(f"plx-engine: {argv[0]}: {exc.strerror}")
        return 126


def run_owned(engine: str, argv: List[str], **kwargs) -> int:
    """Run an engine as an owned child in the wrapper's own process group (a host
    that signals the whole group must still reach it). SIGTERM/SIGINT stop the
    engine, then the wrapper exits 143/130 and the exit path still records usage."""
    proc = spawn(argv, **kwargs)
    if isinstance(proc, int):
        return proc
    interrupt_signals()
    try:
        returncode = proc.wait()
    except Interrupted as stop:
        default_signals()
        _stop_owned(proc)
        name = "INT" if stop.signum == signal.SIGINT else "TERM"
        say(f"plx-engine: {engine} lane interrupted by SIG{name}; the engine process was stopped")
        raise SystemExit(130 if stop.signum == signal.SIGINT else 143)
    finally:
        default_signals()
    return exit_status(returncode)


def _stop_owned(proc: subprocess.Popen) -> None:
    """SIGTERM, up to 10 s grace, then SIGKILL; always reap."""
    try:
        proc.send_signal(signal.SIGTERM)
    except OSError:
        pass
    try:
        proc.wait(timeout=10)
    except subprocess.TimeoutExpired:
        try:
            proc.kill()
        except OSError:
            pass
        proc.wait()


# --------------------------------------------------------------------------- #
# Lane metadata parsing
# --------------------------------------------------------------------------- #


def events(path: str) -> Iterator[dict]:
    """JSON objects, one per line, from an engine's JSONL stream; junk is skipped."""
    try:
        handle = open(path, errors="replace")
    except OSError:
        return
    with handle:
        for line in handle:
            line = line.strip()
            if not line.startswith("{"):
                continue
            try:
                value = json.loads(line)
            except ValueError:
                continue
            if isinstance(value, dict):
                yield value


def document(path: str) -> dict:
    try:
        value = json.loads(Path(path).read_text(errors="replace"))
    except (OSError, ValueError):
        return {}
    return value if isinstance(value, dict) else {}


def add(*parts):
    return None if any(part is None for part in parts) else sum(parts)


def tally(rows, keys) -> dict:
    """Sum per-model rows; a key nobody reported stays None."""
    totals = {}
    for key in keys:
        values = [row.get(key) for row in rows if row.get(key) is not None]
        totals[key] = sum(values) if values else None
    return totals


def mismatch(requested: str, served: List[str]) -> bool:
    """True only when the engine named its models and none is the requested one."""
    wanted = requested.split("[", 1)[0].lower()
    return bool(served) and wanted != "auto" and not any(wanted in name.lower() for name in served)


# --------------------------------------------------------------------------- #
# Served-model check and usage record
# --------------------------------------------------------------------------- #

Parser = Callable[[str], dict]


def warn_served(lane: Lane, parse: Parser) -> None:
    """Accept any model ID, but say so when the engine served a different one."""
    try:
        names = sorted(set(parse(lane.usage_src)["served"]))
        if mismatch(lane.model, names):
            say(f"plx-engine: warning: requested {lane.model} but {lane.engine} served "
                f"{', '.join(names)}")
    except Exception:
        pass


def write_usage(lane: Lane, parse: Parser, rc: int) -> None:
    """Usage is recorded for every launched lane, including failures and interrupts."""
    if lane.start_ts is None or not lane.usage:
        return
    try:
        seconds = int(time.time()) - lane.start_ts
        data = parse(lane.usage_src) if lane.usage_src else dict(served=[], source="none")
        names = sorted(set(data.get("served") or []))
        cost = data.get("cost")
        record = dict(engine=lane.engine, model=lane.model, served_models=names or None,
                      model_mismatch=mismatch(lane.model, names), effort=lane.effort or None,
                      mode=lane.mode, exit_code=int(rc), wall_seconds=int(seconds),
                      prompt_tokens=data.get("prompt"), cached_tokens=data.get("cached"),
                      cache_write_tokens=data.get("cache_write"),
                      completion_tokens=data.get("completion"),
                      reasoning_tokens=data.get("reasoning"), cost_usd=cost,
                      cost_source="vendor" if cost is not None else "unknown",
                      num_turns=data.get("turns"), source=data.get("source"))
        temporary = Path(lane.usage + ".tmp")
        temporary.write_text(json.dumps(record, indent=2) + "\n")
        os.replace(temporary, lane.usage)
    except Exception:
        pass
