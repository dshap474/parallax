#!/usr/bin/env bash
# Shared helpers for the Parallax test harness.
# Source this from a test script: . "$(dirname "$0")/lib.sh"
# Avoids bash-4 features (no mapfile) so it runs on macOS's stock bash 3.2.

# Repo root = parent of this tests/ dir.
PLX_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PLX_ROOT
# The plugin path variable the skills use. The harness points it at the repo
# itself so referenced paths resolve exactly as they would when installed.
export CLAUDE_PLUGIN_ROOT="$PLX_ROOT"

PASS=0
FAIL=0
SKIP=0

if [ -t 1 ]; then
  C_GREEN="$(printf '\033[32m')"; C_RED="$(printf '\033[31m')"
  C_YEL="$(printf '\033[33m')"; C_DIM="$(printf '\033[2m')"; C_OFF="$(printf '\033[0m')"
else
  C_GREEN=""; C_RED=""; C_YEL=""; C_DIM=""; C_OFF=""
fi

_pass() { PASS=$((PASS+1)); printf '  %s✓%s %s\n' "$C_GREEN" "$C_OFF" "$1"; }
_fail() { FAIL=$((FAIL+1)); printf '  %s✗%s %s\n' "$C_RED" "$C_OFF" "$1"; }
_skip() { SKIP=$((SKIP+1)); printf '  %s•%s %s%s%s\n' "$C_YEL" "$C_OFF" "$C_DIM" "$1" "$C_OFF"; }
_head() { printf '\n%s== %s ==%s\n' "$C_DIM" "$1" "$C_OFF"; }

# assert_file <relpath-from-root> [label]
assert_file() {
  local rel="$1" label="${2:-$1}"
  if [ -e "$PLX_ROOT/$rel" ]; then _pass "$label"; else _fail "missing: $rel"; fi
}

# assert_exec <relpath-from-root>
assert_exec() {
  local rel="$1"
  if [ -x "$PLX_ROOT/$rel" ]; then _pass "executable: $rel"; else _fail "not executable: $rel"; fi
}

# assert_contains <string> <file> [label]
assert_contains() {
  local needle="$1" file="$2" label="${3:-contains \"$1\"}"
  if grep -qF -- "$needle" "$file" 2>/dev/null; then _pass "$label"; else _fail "$label"; fi
}

# Build an isolated git repo from tests/fixture and echo its path.
# Caller is responsible for rm -rf; or trap it.
make_tmp_repo() {
  local dst
  dst="$(mktemp -d "${TMPDIR:-/tmp}/plx-fixture.XXXXXX")"
  # Resolve symlinks (macOS /var -> /private/var) so the path matches what
  # `git rev-parse --show-toplevel` reports from inside the repo.
  dst="$(cd "$dst" && pwd -P)"
  cp -R "$PLX_ROOT/tests/fixture/." "$dst/"
  (
    cd "$dst" || exit 1
    git init -q
    git add -A
    git -c user.email=test@example.com -c user.name=plx-test commit -qm "fixture init"
  ) >/dev/null 2>&1
  printf '%s\n' "$dst"
}

summary() {
  printf '\n%s---%s\n' "$C_DIM" "$C_OFF"
  printf 'pass %s%d%s  fail %s%d%s  skip %s%d%s\n' \
    "$C_GREEN" "$PASS" "$C_OFF" "$C_RED" "$FAIL" "$C_OFF" "$C_YEL" "$SKIP" "$C_OFF"
  [ "$FAIL" -eq 0 ]
}
