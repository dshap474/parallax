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
export XDG_CONFIG_HOME="$WORK/xdg-config"
mkdir -p "$XDG_CONFIG_HOME"
echo "package: ${PLX_PACKAGE:-claude} ($PLUGIN_ROOT)"
echo "tmp target repo: $REPO"

_head "bin tools answer --help"
for t in plx-engine plx-preflight plx-config plx-skill plx-link-claude plx-eval plx-clean-temp; do
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
"$PLUGIN_ROOT/bin/plx-eval" --bogus >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 2 ]; then _pass "plx-eval --bogus exits 2"; else _fail "plx-eval expected exit 2, got $rc"; fi

_head "plx-engine resolves rubrics (--print-rubric, model-free)"
if "$PLUGIN_ROOT/bin/plx-engine" --print-rubric reviewer-correctness 2>/dev/null | grep -qi "review"; then
  _pass "--print-rubric reviewer-correctness emits the rubric"
else
  _fail "--print-rubric reviewer-correctness failed"
fi
for rubric in kiss-reuse kiss-simplification kiss-efficiency kiss-altitude; do
  if "$PLUGIN_ROOT/bin/plx-engine" --print-rubric "$rubric" 2>/dev/null |
     grep -Fq 'Parallax KISS rubric'; then
    _pass "--print-rubric $rubric emits the rubric"
  else
    _fail "--print-rubric $rubric failed"
  fi
done

# Neutralize ambient collection — enabled cases set an explicit temp destination.
unset PLX_TRACE_DB || true
export -n PLX_TRACE_DB 2>/dev/null || true

_head "plx-eval loads deterministic local config"
autoload_eval="$WORK/eval-autoload/traces.db"
explicit_eval="$WORK/eval-explicit/traces.db"
mkdir -p "$XDG_CONFIG_HOME/parallax" "$(dirname "$autoload_eval")" "$(dirname "$explicit_eval")"
printf '%s\n' \
  "UNRELATED=\$(touch $WORK/config-must-not-execute)" \
  "PLX_TRACE_DB=$autoload_eval" \
  > "$XDG_CONFIG_HOME/parallax/env"
autoload_out="$WORK/autoload-doctor.txt"
env -u PLX_TRACE_DB "$PLUGIN_ROOT/bin/plx-eval" doctor > "$autoload_out" 2>&1
rc=$?
if [ "$rc" -eq 0 ] && grep -Fq "destination=$autoload_eval" "$autoload_out" &&
   [ ! -e "$WORK/config-must-not-execute" ]; then
  _pass "local config enables collection without executing shell syntax"
else
  _fail "local config autoload failed (exit $rc)"
fi
explicit_out="$WORK/explicit-doctor.txt"
PLX_TRACE_DB="$explicit_eval" "$PLUGIN_ROOT/bin/plx-eval" doctor > "$explicit_out" 2>&1
rc=$?
if [ "$rc" -eq 0 ] && grep -Fq "destination=$explicit_eval" "$explicit_out"; then
  _pass "explicit PLX_TRACE_DB overrides local config"
else
  _fail "explicit PLX_TRACE_DB precedence failed (exit $rc)"
fi
rm "$XDG_CONFIG_HOME/parallax/env"

_head "plx-engine defaults Grok settings and passes explicit overrides"
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
  --prompt-file "$fake_prompt" --model grok-composer-2.5-fast --effort xhigh \
  --out "$fake_out" --log "$fake_log" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 0 ] &&
   grep -qx "grok-composer-2.5-fast" "$fake_args" &&
   grep -qx "xhigh" "$fake_args"; then
  _pass "Grok model and effort overrides pass through"
else
  _fail "Grok overrides did not pass through (exit $rc)"
fi
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
  --prompt-file "$fake_prompt" --model gpt-5.5 --effort xhigh \
  --out "$fake_out" --log "$fake_log" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 0 ] &&
   grep -qx "gpt-5.5" "$fake_codex_args" &&
   grep -qx "model_reasoning_effort=xhigh" "$fake_codex_args"; then
  _pass "Codex model and effort overrides pass through"
else
  _fail "Codex overrides did not pass through (exit $rc)"
fi

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
  assert_contains "gpt-5.6-sol" "$cxa_args" "persistent Codex model defaults to GPT-5.6 Sol"
  assert_contains "medium" "$cxa_args" "persistent Codex effort defaults to medium"
  assert_contains "$PLUGIN_ROOT/bin/../tools/codex-app-client" "$cxa_args" "uses the packaged app client"
  assert_contains "$WORK/cache/parallax/codex-app-client" "$cxa_env" "uv environment stays outside the plugin"
  assert_contains "reply OK" "$cxa_prompt" "prompt is sent over stdin"

  PATH="$fake_bin:$PATH" PLX_CXA_ARGS_FILE="$cxa_args" \
    PLX_CXA_PROMPT_FILE="$cxa_prompt" PLX_CXA_ENV_FILE="$cxa_env" \
    XDG_CACHE_HOME="$WORK/cache" \
    "$PLUGIN_ROOT/bin/plx-codex-thread" resume --thread thread-123 \
    --repo "$REPO" --mode rw --prompt-file "$fake_prompt" \
    --model gpt-5.6-terra --effort low > "$WORK/cxa-resume.json"
  rc=$?
  if [ "$rc" -eq 0 ]; then _pass "persistent resume exits 0"; else _fail "persistent resume exits $rc"; fi
  assert_contains "thread-123" "$cxa_args" "resume passes the thread ID"
  assert_contains "edit" "$cxa_args" "rw maps to edit"
  assert_contains "gpt-5.6-terra" "$cxa_args" "persistent model override passes through"
  assert_contains "low" "$cxa_args" "persistent effort override passes through"
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

fake_claude_args="$WORK/claude-args.txt"
fake_claude_prompt="$WORK/claude-prompt.md"
printf '%s\n' '#!/usr/bin/env bash' \
  '# Fake Claude CLI — records argv and returns one successful response.' \
  'printf '\''%s\n'\'' "$@" > "$PLX_CLAUDE_ARGS_FILE"' \
  'cat > "$PLX_CLAUDE_PROMPT_FILE"' \
  'printf '\''OK\n'\''' \
  > "$fake_bin/claude"
chmod +x "$fake_bin/claude"

PATH="$fake_bin:$PATH" PLX_CLAUDE_ARGS_FILE="$fake_claude_args" \
  PLX_CLAUDE_PROMPT_FILE="$fake_claude_prompt" \
  "$PLUGIN_ROOT/bin/plx-engine" --engine claude --mode ro --repo "$REPO" \
  --prompt-file "$fake_prompt" --model sonnet --effort max \
  --out "$fake_out" --log "$fake_log" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 0 ] &&
   grep -qx "sonnet" "$fake_claude_args" &&
   grep -qx "max" "$fake_claude_args"; then
  _pass "Claude model and effort overrides pass through"
else
  _fail "Claude overrides did not pass through (exit $rc)"
fi
for flag in --safe-mode --no-session-persistence --strict-mcp-config --mcp-config; do
  assert_contains "$flag" "$fake_claude_args" "Claude ro receives $flag"
done
assert_contains "dontAsk" "$fake_claude_args" "Claude ro cannot prompt for broader permissions"
assert_contains "Read,Grep,Glob" "$fake_claude_args" "Claude ro exposes only read tools"
assert_contains '"failIfUnavailable":true' "$fake_claude_args" "Claude sandbox fails closed"
assert_contains '"strictAllowlist":true' "$fake_claude_args" "Claude network allowlist is strict"
assert_contains '{"mcpServers":{}}' "$fake_claude_args" "Claude receives an empty MCP configuration"
if grep -qx -- '--setting-sources' "$fake_claude_args"; then
  _fail "Claude loads ambient setting sources"
else
  _pass "Claude loads no ambient setting sources"
fi
if grep -qx "Bash" "$fake_claude_args" || grep -q "Edit\\|Write" "$fake_claude_args"; then
  _fail "Claude ro exposes a mutation tool"
else
  _pass "Claude ro exposes no mutation tool"
fi

PATH="$fake_bin:$PATH" PLX_CLAUDE_ARGS_FILE="$fake_claude_args" \
  PLX_CLAUDE_PROMPT_FILE="$fake_claude_prompt" \
  "$PLUGIN_ROOT/bin/plx-engine" --engine claude --mode rw --repo "$REPO" \
  --prompt-file "$fake_prompt" --out "$fake_out" --log "$fake_log" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then _pass "Claude rw invocation exits 0"; else _fail "Claude rw invocation exits $rc"; fi
assert_contains "Bash" "$fake_claude_args" "Claude rw exposes sandboxed Bash"
assert_contains "acceptEdits" "$fake_claude_args" "Claude rw accepts sandboxed operations"
assert_contains "use sandboxed Bash" "$fake_claude_prompt" "Claude rw prompt explains its write path"
if grep -qxE 'Edit|Write|[^,]*Edit,[^,]*|[^,]*Write,[^,]*' "$fake_claude_args"; then
  _fail "Claude rw exposes direct Edit or Write"
else
  _pass "Claude rw excludes direct Edit and Write"
fi

_head "plx-clean-temp confines recursive cleanup"
clean_target="$(mktemp -d "${TMPDIR:-/tmp}/plx-clean-smoke.XXXXXX")"
mkdir -p "$clean_target/a/b"
printf '%s\n' x > "$clean_target/a/b/file"
if "$PLUGIN_ROOT/bin/plx-clean-temp" "$clean_target" && [ ! -e "$clean_target" ]; then
  _pass "plx-clean-temp removes a prefixed temp tree"
else
  _fail "plx-clean-temp failed to remove a valid tree"
fi
outside_target="$WORK/not-a-plx-temp"
mkdir -p "$outside_target"
if "$PLUGIN_ROOT/bin/plx-clean-temp" "$outside_target" >/dev/null 2>&1; then
  _fail "plx-clean-temp accepted a non-temp target"
else
  _pass "plx-clean-temp refuses targets outside the temp root"
fi

# --------------------------------------------------------------------------- #
# SQLite trace recorder (model-free, hermetic)
# --------------------------------------------------------------------------- #

_head "plx-eval disabled no-op and doctor"
disabled_config="$WORK/disabled-config"
mkdir -p "$disabled_config"
env -u PLX_TRACE_DB XDG_CONFIG_HOME="$disabled_config" \
  "$PLUGIN_ROOT/bin/plx-eval" doctor > "$WORK/disabled-doctor.txt" 2>&1
rc=$?
if [ "$rc" -eq 0 ] && grep -qi disabled "$WORK/disabled-doctor.txt"; then
  _pass "doctor reports disabled when PLX_TRACE_DB is unset"
else
  _fail "doctor disabled path failed (exit $rc)"
fi
db_before="$(find "$WORK" -name '*.db' | wc -l | tr -d ' ')"
PATH="$fake_bin:$PATH" PLX_GROK_ARGS_FILE="$fake_args" \
  env -u PLX_TRACE_DB XDG_CONFIG_HOME="$disabled_config" \
  "$PLUGIN_ROOT/bin/plx-engine" --engine grok --mode ro --repo "$REPO" \
  --prompt-file "$fake_prompt" --out "$fake_out" --log "$fake_log" >/dev/null
rc=$?
db_after="$(find "$WORK" -name '*.db' | wc -l | tr -d ' ')"
if [ "$rc" -eq 0 ] && [ "$db_before" = "$db_after" ]; then
  _pass "disabled engine path creates no trace database"
else
  _fail "disabled engine path wrote a database or failed"
fi

_head "plx-eval config, grouped lanes, and full trace bodies"
printf '%s\n' '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' "$@" > "$PLX_GROK_ARGS_FILE"' \
  'echo TRACE_BODY >&2' \
  'printf '\''{"text":"OK","stopReason":"EndTurn","sessionId":""}\n'\''' \
  > "$fake_bin/grok"
chmod +x "$fake_bin/grok"

config_db="$WORK/config-traces/traces.db"
plain_prompt_dir="$WORK/plain-engine-prompts"
mkdir -p "$(dirname "$config_db")" "$XDG_CONFIG_HOME/parallax" "$plain_prompt_dir"
config_prompt="$plain_prompt_dir/config.md"
printf '%s\n' 'config standalone prompt' > "$config_prompt"
printf '%s\n' "PLX_TRACE_DB=$config_db" > "$XDG_CONFIG_HOME/parallax/env"
PATH="$fake_bin:$PATH" PLX_GROK_ARGS_FILE="$fake_args" env -u PLX_TRACE_DB \
  "$PLUGIN_ROOT/bin/plx-engine" --engine grok --mode ro --repo "$REPO" \
  --prompt-file "$config_prompt" --out "$fake_out" --log "$fake_log" >/dev/null
rc=$?
if [ "$rc" -eq 0 ] && python3 - "$config_db" <<'PY'
import sqlite3, sys
con = sqlite3.connect(sys.argv[1])
assert con.execute("select count(*) from runs").fetchone()[0] == 1
assert con.execute("select count(*) from lanes").fetchone()[0] == 1
assert con.execute("select ended_at is not null from runs").fetchone()[0] == 1
PY
then
  _pass "literal local config activates standalone SQLite capture"
else
  _fail "local config standalone capture failed"
fi
rm "$XDG_CONFIG_HOME/parallax/env"

trace_db="$WORK/grouped-traces/traces.db"
mkdir -p "$(dirname "$trace_db")"
group_tmp="$(mktemp -d "$WORK/plx-dev.XXXXXX")"
task_body="SECRET_TASK_BODY_IS_STORED"
shape_body="Sizing: 2 workers (grok, medium)"
printf '%s\n' "$task_body" > "$group_tmp/task.md"
printf '%s\n' "$shape_body" > "$group_tmp/shape.txt"
printf '%s\n' 'lane A SECRET_PROMPT_BODY' > "$group_tmp/lane-a.md"
printf '%s\n' 'lane B SECRET_PROMPT_BODY' > "$group_tmp/lane-b.md"

PATH="$fake_bin:$PATH" PLX_GROK_ARGS_FILE="$fake_args" PLX_TRACE_DB="$trace_db" \
  "$PLUGIN_ROOT/bin/plx-engine" --engine grok --mode ro --repo "$REPO" \
  --prompt-file "$group_tmp/lane-a.md" --rubric worker \
  --out "$group_tmp/out-a.md" --log "$group_tmp/log-a.log" >/dev/null &
pid_a=$!
PATH="$fake_bin:$PATH" PLX_GROK_ARGS_FILE="$fake_args" PLX_TRACE_DB="$trace_db" \
  "$PLUGIN_ROOT/bin/plx-engine" --engine grok --mode ro --repo "$REPO" \
  --prompt-file "$group_tmp/lane-b.md" --rubric reviewer-correctness \
  --out "$group_tmp/out-b.md" --log "$group_tmp/log-b.log" >/dev/null &
pid_b=$!
wait "$pid_a"; rc_a=$?
wait "$pid_b"; rc_b=$?
PLX_TRACE_DB="$trace_db" "$PLUGIN_ROOT/bin/plx-eval" finish \
  --skill dev --host "${PLX_PACKAGE:-claude}" --repo "$REPO" --run-dir "$group_tmp" \
  --task-file "$group_tmp/task.md" --shape-file "$group_tmp/shape.txt" \
  --outcome pass --verification pass >/dev/null
finish_rc=$?
if [ "$rc_a" -eq 0 ] && [ "$rc_b" -eq 0 ] && [ "$finish_rc" -eq 0 ]; then
  _pass "concurrent grouped lanes and finish exit 0"
else
  _fail "grouped capture failed (a=$rc_a b=$rc_b finish=$finish_rc)"
fi
if python3 - "$trace_db" "$(basename "$group_tmp")" "$task_body" "$shape_body" <<'PY'
import hashlib, sqlite3, sys
db, run_id, task, shape = sys.argv[1:]
con = sqlite3.connect(db)
con.execute("pragma foreign_keys=on")
run = con.execute(
    "select skill, host, task, routing_summary, outcome, verification, ended_at from runs where id=?",
    (run_id,),
).fetchone()
assert run[0] == "dev"
assert run[1] in {"claude", "codex"}
assert run[2:6] == (task + "\n", shape + "\n", "pass", "pass")
assert run[6]
lanes = con.execute(
    "select prompt, trace, final_output, trace_sha256, exit_code from lanes where run_id=? order by role",
    (run_id,),
).fetchall()
assert len(lanes) == 2
for prompt, trace, output, digest, exit_code in lanes:
    assert "SECRET_PROMPT_BODY" in prompt
    assert trace == "TRACE_BODY\n"
    assert output == "OK\n"
    assert digest == hashlib.sha256(trace.encode()).hexdigest()
    assert exit_code == 0
assert con.execute("pragma user_version").fetchone()[0] == 1
assert con.execute("pragma integrity_check").fetchone()[0] == "ok"
PY
then
  _pass "schema v1 stores complete task, prompt, trace, output, and digest"
else
  _fail "grouped database content is incorrect"
fi

_head "plx-eval standalone, failure, incomplete, and schema guards"
standalone_db="$WORK/standalone-traces/traces.db"
mkdir -p "$(dirname "$standalone_db")"
standalone_prompt="$plain_prompt_dir/standalone.md"
printf '%s\n' 'standalone SECRET_STANDALONE_PROMPT' > "$standalone_prompt"
PATH="$fake_bin:$PATH" PLX_GROK_ARGS_FILE="$fake_args" PLX_TRACE_DB="$standalone_db" \
  "$PLUGIN_ROOT/bin/plx-engine" --engine grok --mode ro --repo "$REPO" \
  --prompt-file "$standalone_prompt" \
  --out "$WORK/standalone-out.md" --log "$WORK/standalone.log" >/dev/null
rc=$?
if [ "$rc" -eq 0 ] && python3 - "$standalone_db" <<'PY'
import sqlite3, sys
con = sqlite3.connect(sys.argv[1])
run = con.execute("select skill, outcome, verification, ended_at from runs").fetchone()
lane = con.execute("select prompt, trace, final_output from lanes").fetchone()
assert run[0:3] == ("standalone-lane", "pass", "not-run") and run[3]
assert "SECRET_STANDALONE_PROMPT" in lane[0]
assert lane[1:] == ("TRACE_BODY\n", "OK\n")
PY
then
  _pass "ungrouped engine creates and closes one standalone run"
else
  _fail "standalone capture is incorrect"
fi

printf '%s\n' '#!/usr/bin/env bash' 'echo fail-noise >&2' 'exit 1' > "$fake_bin/grok"
chmod +x "$fake_bin/grok"
fail_db="$WORK/fail-traces/traces.db"
mkdir -p "$(dirname "$fail_db")"
fail_prompt="$plain_prompt_dir/fail.md"
printf '%s\n' 'fail prompt' > "$fail_prompt"
PATH="$fake_bin:$PATH" PLX_TRACE_DB="$fail_db" \
  "$PLUGIN_ROOT/bin/plx-engine" --engine grok --mode ro --repo "$REPO" \
  --prompt-file "$fail_prompt" --out "$WORK/fail-out.md" --log "$WORK/fail.log" \
  >/dev/null 2>"$WORK/fail-stderr.txt"
fail_rc=$?
if [ "$fail_rc" -eq 1 ] && python3 - "$fail_db" <<'PY'
import sqlite3, sys
con = sqlite3.connect(sys.argv[1])
assert con.execute("select outcome from runs").fetchone()[0] == "fail"
assert con.execute("select exit_code, trace from lanes").fetchone() == (1, "fail-noise\n")
PY
then
  _pass "failed engine preserves exit 1 and records the failed lane"
else
  _fail "failed lane recording drift"
fi

printf '%s\n' '#!/usr/bin/env bash' \
  'echo "Failed to initialize Seatbelt workspace sandbox: Operation not permitted" >&2' \
  'exit 1' > "$fake_bin/grok"
chmod +x "$fake_bin/grok"
PATH="$fake_bin:$PATH" env -u PLX_TRACE_DB XDG_CONFIG_HOME="$disabled_config" \
  "$PLUGIN_ROOT/bin/plx-engine" --engine grok --mode rw --repo "$REPO" \
  --prompt-file "$fail_prompt" --out "$WORK/seatbelt-out.md" --log "$WORK/seatbelt.log" \
  >/dev/null 2>"$WORK/seatbelt-stderr.txt"
seatbelt_rc=$?
if [ "$seatbelt_rc" -eq 1 ] && grep -Fq "PLX_GROK_SANDBOX_UNAVAILABLE" "$WORK/seatbelt-stderr.txt"; then
  _pass "Grok Seatbelt startup failure remains classified"
else
  _fail "Grok Seatbelt startup failure classification drift"
fi

printf '%s\n' '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' "$@" > "$PLX_GROK_ARGS_FILE"' \
  'printf '\''{"text":"OK","stopReason":"EndTurn","sessionId":""}\n'\''' \
  > "$fake_bin/grok"
chmod +x "$fake_bin/grok"
bad_db="$WORK/missing-parent/traces.db"
PATH="$fake_bin:$PATH" PLX_TRACE_DB="$bad_db" PLX_GROK_ARGS_FILE="$fake_args" \
  "$PLUGIN_ROOT/bin/plx-engine" --engine grok --mode ro --repo "$REPO" \
  --prompt-file "$fake_prompt" --out "$fake_out" --log "$fake_log" \
  >/dev/null 2>"$WORK/bad-db-stderr.txt"
rc=$?
if [ "$rc" -eq 0 ] && [ ! -e "$bad_db" ]; then
  _pass "trace write failure does not change engine exit 0"
else
  _fail "trace write failure altered engine behavior"
fi

zero_db="$WORK/zero-lane/traces.db"
mkdir -p "$(dirname "$zero_db")"
PLX_TRACE_DB="$zero_db" "$PLUGIN_ROOT/bin/plx-eval" finish \
  --skill init --host "${PLX_PACKAGE:-claude}" --repo "$REPO" \
  --outcome pass --verification not-run >/dev/null
if python3 - "$zero_db" <<'PY'
import sqlite3, sys
con = sqlite3.connect(sys.argv[1])
assert con.execute("select skill, outcome, ended_at is not null from runs").fetchone() == ("init", "pass", 1)
assert con.execute("select count(*) from lanes").fetchone()[0] == 0
PY
then
  _pass "host-only finish creates a closed zero-lane run"
else
  _fail "zero-lane run capture failed"
fi

incomplete_tmp="$(mktemp -d "$WORK/plx-plan.XXXXXX")"
printf '%s\n' incomplete > "$incomplete_tmp/prompt.md"
PATH="$fake_bin:$PATH" PLX_TRACE_DB="$trace_db" PLX_GROK_ARGS_FILE="$fake_args" \
  "$PLUGIN_ROOT/bin/plx-engine" --engine grok --mode ro --repo "$REPO" \
  --prompt-file "$incomplete_tmp/prompt.md" \
  --out "$incomplete_tmp/out.md" --log "$incomplete_tmp/log.md" >/dev/null
if python3 - "$trace_db" "$(basename "$incomplete_tmp")" <<'PY'
import sqlite3, sys
con = sqlite3.connect(sys.argv[1])
assert con.execute("select skill, ended_at, outcome from runs where id=?", (sys.argv[2],)).fetchone() == ("plan", None, None)
PY
then
  _pass "grouped lane remains incomplete until skill finish"
else
  _fail "incomplete grouped run state is incorrect"
fi

doctor_ok="$WORK/doctor-ok.txt"
PLX_TRACE_DB="$trace_db" "$PLUGIN_ROOT/bin/plx-eval" doctor > "$doctor_ok" 2>&1
if [ "$?" -eq 0 ] && grep -Fq 'runs=' "$doctor_ok" && grep -Fq 'lanes=' "$doctor_ok"; then
  _pass "doctor validates schema and reports counts"
else
  _fail "doctor failed on a valid database"
fi

future_db="$WORK/future-schema.db"
python3 - "$future_db" <<'PY'
import sqlite3, sys
con = sqlite3.connect(sys.argv[1])
con.execute("pragma user_version=2")
con.commit()
PY
PLX_TRACE_DB="$future_db" "$PLUGIN_ROOT/bin/plx-eval" doctor >/dev/null 2>&1
if [ "$?" -eq 1 ]; then
  _pass "unknown schema version fails closed"
else
  _fail "unknown schema version was accepted"
fi

if python3 - "$trace_db" <<'PY'
import sqlite3, sys
con = sqlite3.connect(sys.argv[1])
con.execute("pragma foreign_keys=on")
try:
    con.execute("insert into lanes(id,run_id,role,engine,model,effort,mode,started_at) values('bad-fk','missing','r','grok','m','e','ro','now')")
except sqlite3.IntegrityError:
    pass
else:
    raise AssertionError("foreign key accepted")
try:
    con.execute("insert into lanes(id,run_id,role,engine,model,effort,mode,candidates_json,started_at) values('bad-json',(select id from runs limit 1),'r','grok','m','e','ro','nope','now')")
except sqlite3.IntegrityError:
    pass
else:
    raise AssertionError("invalid JSON accepted")
PY
then
  _pass "foreign-key and JSON constraints are active"
else
  _fail "schema constraints drifted"
fi

# Shared-copy check is covered by check-plugin; both packages smoke via run.sh.

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
out="$WORK/kiss-skill.txt"
"$PLUGIN_ROOT/bin/plx-skill" kiss > "$out" 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then _pass "kiss exits 0"; else _fail "kiss exit $rc"; fi
assert_contains "## KISS" "$out" "emits the KISS pipeline"
if "$PLUGIN_ROOT/bin/plx-skill" no-such-skill >/dev/null 2>&1; then
  _fail "should reject unknown skill"
else
  _pass "non-zero exit on unknown skill"
fi
if "$PLUGIN_ROOT/bin/plx-skill" simplify >/dev/null 2>&1; then
  _fail "should reject retired simplify skill"
else
  _pass "non-zero exit on retired simplify skill"
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

_head "plx-preflight probes the requested Grok sandbox mode"
if "$PLUGIN_ROOT/bin/plx-preflight" --repo "$REPO" --grok-mode rw >/dev/null 2>&1; then
  _fail "--grok-mode without a Grok selector should exit 2"
else
  rc=$?
  if [ "$rc" -eq 2 ]; then _pass "--grok-mode requires a Grok selector"; else _fail "expected exit 2, got $rc"; fi
fi
if "$PLUGIN_ROOT/bin/plx-preflight" --repo "$REPO" --require-grok --grok-mode invalid >/dev/null 2>&1; then
  _fail "invalid --grok-mode should exit 2"
else
  rc=$?
  if [ "$rc" -eq 2 ]; then _pass "invalid --grok-mode exits 2"; else _fail "expected exit 2, got $rc"; fi
fi
printf '%s\n' '#!/usr/bin/env bash' \
  '# Fake Grok CLI — records argv and returns one successful headless envelope.' \
  'printf '\''%s\n'\'' "$@" > "$PLX_GROK_ARGS_FILE"' \
  'printf '\''{"text":"OK","stopReason":"EndTurn","sessionId":""}\n'\''' \
  > "$fake_bin/grok"
chmod +x "$fake_bin/grok"
PATH="$fake_bin:$PATH" PLX_GROK_ARGS_FILE="$fake_args" \
  "$PLUGIN_ROOT/bin/plx-preflight" --repo "$REPO" --require-grok > "$out" 2>&1
rc=$?
ro_probe_repo="$(awk 'previous == "--cwd" { print; exit } { previous=$0 }' "$fake_args")"
if [ "$rc" -eq 0 ] && [ "$ro_probe_repo" = "$REPO" ] &&
   grep -qx "read-only" "$fake_args" &&
   grep -Fq -- "- grok: ok (mode=ro)" "$out"; then
  _pass "Grok read-only preflight keeps the requested repository"
else
  _fail "Grok read-only preflight mode drift"
fi
PATH="$fake_bin:$PATH" PLX_GROK_ARGS_FILE="$fake_args" \
  "$PLUGIN_ROOT/bin/plx-preflight" --repo "$REPO" --require-grok --grok-mode rw > "$out" 2>&1
rc=$?
rw_probe_repo="$(awk 'previous == "--cwd" { print; exit } { previous=$0 }' "$fake_args")"
if [ "$rc" -eq 0 ] && [ "$rw_probe_repo" != "$REPO" ] &&
   printf '%s\n' "$rw_probe_repo" | grep -q '/plx-preflight\.[^/]*/grok-workspace-probe$' &&
   grep -qx "workspace" "$fake_args" &&
   grep -Fq -- "- grok: ok (mode=rw)" "$out"; then
  _pass "Grok workspace preflight uses a disposable repository"
else
  _fail "Grok workspace preflight did not isolate the target (repo=$rw_probe_repo)"
fi

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
    for grok_mode in ro rw; do
      if "$PLUGIN_ROOT/bin/plx-preflight" --repo "$REPO" \
        --require-grok --grok-mode "$grok_mode" >/dev/null 2>&1; then
        _pass "grok preflight $grok_mode ok"
      else
        _fail "grok present but $grok_mode preflight failed"
      fi
    done
  else
    _skip "grok not installed — skipped"
  fi
else
  _head "engine probes"
  _skip "skipped (pass --with-engines to probe codex/grok)"
fi

summary
