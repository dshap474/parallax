#!/usr/bin/env bash
# Smoke-test one packaged runtime against an ISOLATED temporary repository.
# By default no engine (codex/grok) calls are made — preflight is run without
# --require-* so it stays model-free. Pass --with-engines to also probe codex/grok.
# Usage: PLX_PACKAGE=claude|codex tests/smoke-scripts.sh [--with-engines]
set -uo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

WITH_ENGINES=0
if [ "$#" -gt 1 ]; then
  echo "usage: PLX_PACKAGE=claude|codex tests/smoke-scripts.sh [--with-engines]" >&2
  exit 2
fi
case "${1:-}" in
  "") ;;
  --with-engines) WITH_ENGINES=1 ;;
  *) echo "usage: PLX_PACKAGE=claude|codex tests/smoke-scripts.sh [--with-engines]" >&2; exit 2 ;;
esac

REPO="$(make_tmp_repo)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/plx-smoke.XXXXXX")"
trap 'rm -rf "$REPO" "$WORK"' EXIT
echo "package: ${PLX_PACKAGE:-claude} ($PLUGIN_ROOT)"
echo "tmp target repo: $REPO"

_head "bin tools answer --help"
for t in plx-engine plx-preflight plx-config plx-skill plx-link-claude; do
  out="$WORK/help-$t.txt"
  if "$PLUGIN_ROOT/bin/$t" --help > "$out" 2>&1 && grep -q "Usage:" "$out"; then
    _pass "$t --help"
  else
    _fail "$t --help (no Usage block or non-zero exit)"
  fi
done

_head "bin tools reject unknown flags with exit 2"
"$PLUGIN_ROOT/bin/plx-engine" --bogus >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 2 ]; then _pass "plx-engine --bogus exits 2"; else _fail "expected exit 2, got $rc"; fi

_head "plx-engine resolves rubrics (--print-rubric, model-free)"
if "$PLUGIN_ROOT/bin/plx-engine" --print-rubric reviewer-correctness 2>/dev/null | grep -qi "review"; then
  _pass "--print-rubric reviewer-correctness emits the rubric"
else
  _fail "--print-rubric reviewer-correctness failed"
fi

_head "plx-engine pins Grok 4.5 and sizes supported effort"
fake_bin="$WORK/fake-bin"
fake_args="$WORK/grok-args.txt"
fake_prompt="$WORK/grok-prompt.md"
fake_out="$WORK/grok-out.md"
fake_log="$WORK/grok.log"
mkdir -p "$fake_bin"
printf '%s\n' '#!/usr/bin/env bash' \
  '# Fake Grok CLI — records argv and returns one successful headless envelope.' \
  'printf '\''%s\n'\'' "$@" > "$PLX_GROK_ARGS_FILE"' \
  'printf '\''{"text":"OK","stopReason":"EndTurn","sessionId":""}\n'\''' \
  > "$fake_bin/grok"
chmod +x "$fake_bin/grok"
printf '%s\n' 'reply OK' > "$fake_prompt"

PATH="$fake_bin:$PATH" PLX_GROK_ARGS_FILE="$fake_args" \
  "$PLUGIN_ROOT/bin/plx-engine" --engine grok --mode ro --repo "$REPO" \
  --prompt-file "$fake_prompt" --out "$fake_out" --log "$fake_log" >/dev/null
rc=$?
if [ "$rc" -eq 0 ]; then _pass "Grok default invocation exits 0"; else _fail "Grok default invocation exits $rc"; fi
assert_contains "grok-4.5" "$fake_args" "Grok model is grok-4.5"
assert_contains "medium" "$fake_args" "Grok effort defaults to medium"
for flag in --no-auto-update --no-plan --no-subagents --no-memory --no-alt-screen; do
  assert_contains "$flag" "$fake_args" "Grok receives $flag"
done
assert_contains "read-only" "$fake_args" "Grok ro uses read-only sandbox"

for effort in low high; do
  PATH="$fake_bin:$PATH" PLX_GROK_ARGS_FILE="$fake_args" \
    "$PLUGIN_ROOT/bin/plx-engine" --engine grok --mode rw --repo "$REPO" \
    --prompt-file "$fake_prompt" --model grok-4.5 --effort "$effort" \
    --out "$fake_out" --log "$fake_log" >/dev/null
  rc=$?
  if [ "$rc" -eq 0 ] && grep -qx "$effort" "$fake_args"; then
    _pass "Grok accepts explicit $effort effort"
  else
    _fail "Grok failed explicit $effort effort"
  fi
done
assert_contains "workspace" "$fake_args" "Grok rw uses workspace sandbox"

PATH="$fake_bin:$PATH" PLX_GROK_ARGS_FILE="$fake_args" \
  "$PLUGIN_ROOT/bin/plx-engine" --engine grok --mode ro --repo "$REPO" \
  --prompt-file "$fake_prompt" --model grok-composer-2.5-fast \
  --out "$fake_out" --log "$fake_log" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 2 ]; then _pass "Grok rejects Composer"; else _fail "Grok Composer expected exit 2, got $rc"; fi

PATH="$fake_bin:$PATH" PLX_GROK_ARGS_FILE="$fake_args" \
  "$PLUGIN_ROOT/bin/plx-engine" --engine grok --mode ro --repo "$REPO" \
  --prompt-file "$fake_prompt" --effort xhigh \
  --out "$fake_out" --log "$fake_log" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 2 ]; then _pass "Grok rejects xhigh"; else _fail "Grok xhigh expected exit 2, got $rc"; fi
if "$PLUGIN_ROOT/bin/plx-engine" --print-rubric no-such-rubric >/dev/null 2>&1; then
  _fail "should reject unknown rubric"
else
  _pass "non-zero exit on unknown rubric"
fi

_head "plx-engine defaults Codex to GPT-5.6 Sol at medium effort"
fake_codex_args="$WORK/codex-args.txt"
printf '%s\n' '#!/usr/bin/env bash' \
  '# Fake Codex CLI — records argv and writes the requested final output.' \
  'printf '\''%s\n'\'' "$@" > "$PLX_CODEX_ARGS_FILE"' \
  'while [ "$#" -gt 0 ]; do' \
  '  if [ "$1" = "-o" ]; then printf '\''OK\n'\'' > "$2"; exit 0; fi' \
  '  shift' \
  'done' \
  'exit 1' \
  > "$fake_bin/codex"
chmod +x "$fake_bin/codex"

PATH="$fake_bin:$PATH" PLX_CODEX_ARGS_FILE="$fake_codex_args" \
  "$PLUGIN_ROOT/bin/plx-engine" --engine codex --mode rw --repo "$REPO" \
  --prompt-file "$fake_prompt" --out "$fake_out" --log "$fake_log" >/dev/null
rc=$?
if [ "$rc" -eq 0 ]; then _pass "Codex default invocation exits 0"; else _fail "Codex default invocation exits $rc"; fi
assert_contains "gpt-5.6-sol" "$fake_codex_args" "Codex model defaults to GPT-5.6 Sol"
assert_contains "model_reasoning_effort=medium" "$fake_codex_args" "Codex effort defaults to medium"
assert_contains "workspace-write" "$fake_codex_args" "Codex rw uses workspace-write sandbox"

PATH="$fake_bin:$PATH" PLX_CODEX_ARGS_FILE="$fake_codex_args" \
  "$PLUGIN_ROOT/bin/plx-engine" --engine codex --mode ro --repo "$REPO" \
  --prompt-file "$fake_prompt" --model gpt-5.5 \
  --out "$fake_out" --log "$fake_log" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 2 ]; then _pass "Codex rejects GPT-5.5"; else _fail "GPT-5.5 expected exit 2, got $rc"; fi

if [ "${PLX_PACKAGE:-claude}" = "claude" ]; then
  _head "plx-codex-thread starts and resumes app-server threads"
  cxa_args="$WORK/cxa-args.txt"
  cxa_prompt="$WORK/cxa-prompt.md"
  cxa_env="$WORK/cxa-env.txt"
  printf '%s\n' '#!/usr/bin/env bash' \
    '# Fake uv runner for plx-codex-thread smoke tests.' \
    '#' \
    '# Usage: uv <recorded arguments>' \
    'printf '\''%s\n'\'' "$@" > "$PLX_CXA_ARGS_FILE"' \
    'printf '\''%s\n'\'' "$UV_PROJECT_ENVIRONMENT" > "$PLX_CXA_ENV_FILE"' \
    'cat > "$PLX_CXA_PROMPT_FILE"' \
    'printf '\''{"thread_id":"thread-123","status":"completed","final_response":"OK"}\n'\''' \
    > "$fake_bin/uv"
  chmod +x "$fake_bin/uv"

  PATH="$fake_bin:$PATH" PLX_CXA_ARGS_FILE="$cxa_args" \
    PLX_CXA_PROMPT_FILE="$cxa_prompt" PLX_CXA_ENV_FILE="$cxa_env" \
    XDG_CACHE_HOME="$WORK/cache" \
    "$PLUGIN_ROOT/bin/plx-codex-thread" start --repo "$REPO" --mode ro \
    --prompt-file "$fake_prompt" > "$WORK/cxa-start.json"
  rc=$?
  if [ "$rc" -eq 0 ]; then _pass "persistent start exits 0"; else _fail "persistent start exits $rc"; fi
  assert_contains "--persistent" "$cxa_args" "start requests a persistent thread"
  assert_contains "inspect" "$cxa_args" "ro maps to inspect"
  assert_contains "gpt-5.6-sol" "$cxa_args" "persistent Codex model is pinned"
  assert_contains "$PLUGIN_ROOT/bin/../tools/codex-app-client" "$cxa_args" "uses the packaged app client"
  assert_contains "$WORK/cache/parallax/codex-app-client" "$cxa_env" "uv environment stays outside the plugin"
  assert_contains "reply OK" "$cxa_prompt" "prompt is sent over stdin"

  PATH="$fake_bin:$PATH" PLX_CXA_ARGS_FILE="$cxa_args" \
    PLX_CXA_PROMPT_FILE="$cxa_prompt" PLX_CXA_ENV_FILE="$cxa_env" \
    XDG_CACHE_HOME="$WORK/cache" \
    "$PLUGIN_ROOT/bin/plx-codex-thread" resume --thread thread-123 \
    --repo "$REPO" --mode rw --prompt-file "$fake_prompt" > "$WORK/cxa-resume.json"
  rc=$?
  if [ "$rc" -eq 0 ]; then _pass "persistent resume exits 0"; else _fail "persistent resume exits $rc"; fi
  assert_contains "thread-123" "$cxa_args" "resume passes the thread ID"
  assert_contains "edit" "$cxa_args" "rw maps to edit"
  if grep -qx -- '--persistent' "$cxa_args"; then
    _fail "resume unexpectedly requests a new persistent thread"
  else
    _pass "resume does not start a new thread"
  fi
  "$PLUGIN_ROOT/bin/plx-codex-thread" resume --repo "$REPO" --mode ro \
    --prompt-file "$fake_prompt" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 2 ]; then _pass "resume requires a thread ID"; else _fail "missing thread ID expected exit 2, got $rc"; fi
fi

"$PLUGIN_ROOT/bin/plx-engine" --engine claude --mode ro --repo "$REPO" \
  --prompt-file "$fake_prompt" --model sonnet \
  --out "$fake_out" --log "$fake_log" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 2 ]; then _pass "Claude rejects Sonnet"; else _fail "Sonnet expected exit 2, got $rc"; fi

_head "plx-config prints the engine config"
out="$WORK/config.txt"
"$PLUGIN_ROOT/bin/plx-config" > "$out" 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then _pass "exits 0"; else _fail "exit $rc"; fi
assert_contains "pipelines:" "$out" "emits the pipelines map"

_head "plx-skill prints a pipeline skill"
out="$WORK/skill.txt"
"$PLUGIN_ROOT/bin/plx-skill" dev > "$out" 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then _pass "exits 0"; else _fail "exit $rc"; fi
assert_contains "## Pipeline" "$out" "emits the pipeline section"
if "$PLUGIN_ROOT/bin/plx-skill" no-such-skill >/dev/null 2>&1; then
  _fail "should reject unknown skill"
else
  _pass "non-zero exit on unknown skill"
fi
if "$PLUGIN_ROOT/bin/plx-skill" team-dev >/dev/null 2>&1; then
  _fail "should reject a retired skill name (team-dev shipped in no release)"
else
  _pass "non-zero exit on retired skill name"
fi

_head "plx-preflight (model-free)"
out="$WORK/preflight.txt"
"$PLUGIN_ROOT/bin/plx-preflight" --repo "$REPO" > "$out" 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then _pass "exits 0 with no required engines"; else _fail "exit $rc"; fi
assert_contains "preflight_ok: yes" "$out" "reports preflight_ok: yes"

_head "plx-preflight rejects a bad repo path"
if "$PLUGIN_ROOT/bin/plx-preflight" --repo /no/such/repo >/dev/null 2>&1; then
  _fail "should reject missing repo"
else
  _pass "non-zero exit on missing repo"
fi

_head "plx-link-claude mirrors CLAUDE.md symlinks"
echo "# fixture root" > "$REPO/AGENTS.md"
mkdir -p "$REPO/sub"
echo "# nested" > "$REPO/sub/AGENTS.md"
printf 'regular file\n' > "$REPO/sub/CLAUDE.md"
out="$WORK/link.txt"
"$PLUGIN_ROOT/bin/plx-link-claude" "$REPO" > "$out" 2>&1
rc=$?
if [ "$rc" -eq 3 ]; then _pass "exit 3 when a regular CLAUDE.md blocks"; else _fail "expected exit 3, got $rc"; fi
if [ -L "$REPO/CLAUDE.md" ] && [ "$(readlink "$REPO/CLAUDE.md")" = "AGENTS.md" ]; then
  _pass "root CLAUDE.md symlink created"
else
  _fail "root CLAUDE.md symlink missing or wrong"
fi
assert_contains "blocked" "$out" "reports the blocked nested CLAUDE.md"
"$PLUGIN_ROOT/bin/plx-link-claude" "$REPO" --force > "$out" 2>&1
rc=$?
if [ "$rc" -eq 0 ] && [ -L "$REPO/sub/CLAUDE.md" ]; then _pass "--force replaces the regular file"; else _fail "--force failed (exit $rc)"; fi
"$PLUGIN_ROOT/bin/plx-link-claude" "$REPO" > "$out" 2>&1
rc=$?
if [ "$rc" -eq 0 ] && grep -q "0 created, 0 relinked, 2 skipped, 0 blocked" "$out"; then
  _pass "idempotent re-run (all skips)"
else
  _fail "re-run not idempotent (exit $rc)"
fi
if "$PLUGIN_ROOT/bin/plx-link-claude" --bogus >/dev/null 2>&1; then
  _fail "should reject unknown flag"
else
  _pass "non-zero exit on unknown flag"
fi

if [ "$WITH_ENGINES" -eq 1 ]; then
  _head "engine probes (--with-engines)"
  if command -v codex >/dev/null 2>&1; then
    if "$PLUGIN_ROOT/bin/plx-preflight" --repo "$REPO" --require-codex >/dev/null 2>&1; then
      _pass "codex preflight ok"
    else
      _fail "codex present but preflight failed"
    fi
  else
    _skip "codex not installed — skipped"
  fi
  if command -v grok >/dev/null 2>&1; then
    if "$PLUGIN_ROOT/bin/plx-preflight" --repo "$REPO" --require-grok >/dev/null 2>&1; then
      _pass "grok preflight ok"
    else
      _skip "grok present but probe failed (known env-dependent)"
    fi
  else
    _skip "grok not installed — skipped"
  fi
else
  _head "engine probes"
  _skip "skipped (pass --with-engines to probe codex/grok)"
fi

summary
