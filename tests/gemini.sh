#!/usr/bin/env bash
# Exercise Gemini transport flags, settings, output validation, and failures with a fake CLI.
# Usage: bash tests/gemini.sh
set -euo pipefail

# --------------------------------------------------------------------------- #
# Fixtures
# --------------------------------------------------------------------------- #

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/plx-gemini-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin" "$WORK/repo" "$WORK/config"
export XDG_CONFIG_HOME="$WORK/config"
unset PLX_TRACE_DB
printf 'test brief\n' > "$WORK/prompt.md"
cat > "$WORK/bin/uname" <<'FAKE_OS'
#!/bin/sh
echo Darwin
FAKE_OS
cat > "$WORK/bin/gemini" <<'FAKE'
#!/usr/bin/env python3
import json, os, pathlib, sys
args = sys.argv[1:]
settings = json.loads(pathlib.Path(os.environ['GEMINI_CLI_SYSTEM_SETTINGS_PATH']).read_text())
assert '--sandbox' in args and args[args.index('--extensions') + 1] == 'none'
assert os.environ['GEMINI_SANDBOX'] == 'sandbox-exec'
assert os.environ['SEATBELT_PROFILE'] == 'permissive-open'
assert 'SANDBOX' not in os.environ and 'SANDBOX_MOUNTS' not in os.environ
assert settings['context']['includeDirectories'] == []
assert settings['mcp']['allowed'][0].startswith('plx-disabled-')
assert settings['tools']['enableHooks'] is False
assert settings['hooksConfig']['enabled'] is False
assert 'run_shell_command' not in settings['tools']['core']
assert ('write_file' in settings['tools']['core']) == (os.environ['TEST_MODE'] == 'rw')
assert args[args.index('--approval-mode') + 1] == ('auto_edit' if os.environ['TEST_MODE'] == 'rw' else 'default')
assert args[args.index('--model') + 1] == 'test-model'
assert 'test brief' in sys.stdin.read()
assert pathlib.Path.cwd() == pathlib.Path(os.environ['TEST_REPO']).resolve()
case = os.environ.get('TEST_CASE', 'ok')
if case == 'auth':
    print('Please set an Auth method', file=sys.stderr)
    sys.exit(1)
if case == 'project-auth':
    print('ProjectIdRequiredError: set GOOGLE_CLOUD_PROJECT', file=sys.stderr)
    sys.exit(41)
if case == 'failure':
    print('sandbox startup failed', file=sys.stderr)
    sys.exit(1)
if case == 'malformed':
    print('not json')
elif case == 'error':
    print(json.dumps({'response': 'misleading success', 'error': {'message': 'failed'}}))
elif case == 'empty':
    print(json.dumps({'response': ''}))
else:
    print(json.dumps({'response': 'Gemini final answer', 'stats': {}}))
FAKE
chmod +x "$WORK/bin/gemini" "$WORK/bin/uname"
export PATH="$WORK/bin:$PATH" TEST_REPO="$WORK/repo"

# --------------------------------------------------------------------------- #
# Packaged transport contracts
# --------------------------------------------------------------------------- #

for host in claude codex; do
  engine="$ROOT/plugins/$host/plx/bin/plx-engine"
  for mode in ro rw; do
    TEST_MODE="$mode" "$engine" --engine gemini --mode "$mode" --repo "$WORK/repo" \
      --prompt-file "$WORK/prompt.md" --model test-model --rubric reviewer-correctness \
      --stdout > "$WORK/answer"
    grep -qx 'Gemini final answer' "$WORK/answer"
  done
  for case in malformed empty error failure auth project-auth; do
    expected=1
    case "$case" in auth|project-auth) expected=3 ;; esac
    rc=0
    TEST_MODE=ro TEST_CASE="$case" "$engine" --engine gemini --mode ro --repo "$WORK/repo" \
      --prompt-file "$WORK/prompt.md" --model test-model --stdout > "$WORK/answer" 2> "$WORK/error" || rc=$?
    [ "$rc" -eq "$expected" ] && [ ! -s "$WORK/answer" ]
  done
  for args in '--effort high' '--mode full-access' '--build-writer-full-access'; do
    rc=0
    # Deliberate splitting of constant test arguments.
    TEST_MODE=ro "$engine" --engine gemini --mode ro --repo "$WORK/repo" \
      --prompt-file "$WORK/prompt.md" --model test-model --stdout $args > "$WORK/answer" 2>&1 || rc=$?
    [ "$rc" -eq 2 ]
  done
  mkdir -p "$WORK/repo/.gemini"
  printf '{"context":{"includeDirectories":["/tmp"]}}\n' > "$WORK/repo/.gemini/settings.json"
  rc=0
  TEST_MODE=rw "$engine" --engine gemini --mode rw --repo "$WORK/repo" \
    --prompt-file "$WORK/prompt.md" --stdout > "$WORK/answer" 2> "$WORK/error" || rc=$?
  [ "$rc" -ne 0 ] && grep -q 'extra includeDirectories' "$WORK/error"
  rm "$WORK/repo/.gemini/settings.json"
  echo "$host Gemini transport contracts passed"
done
