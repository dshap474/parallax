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
for t in plx-engine plx-preflight plx-config plx-skill plx-link-claude plx-eval; do
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

# Neutralize ambient collection — enabled cases set an explicit temp destination.
unset PLX_EVAL_DIR || true
export -n PLX_EVAL_DIR 2>/dev/null || true

_head "plx-eval loads deterministic local config"
autoload_eval="$WORK/eval-autoload"
explicit_eval="$WORK/eval-explicit"
mkdir -p "$XDG_CONFIG_HOME/parallax" "$autoload_eval" "$explicit_eval"
printf '%s\n' \
  "UNRELATED=\$(touch $WORK/config-must-not-execute)" \
  "PLX_EVAL_DIR=$autoload_eval" \
  > "$XDG_CONFIG_HOME/parallax/env"
autoload_out="$WORK/autoload-doctor.txt"
env -u PLX_EVAL_DIR "$PLUGIN_ROOT/bin/plx-eval" doctor > "$autoload_out" 2>&1
rc=$?
if [ "$rc" -eq 0 ] && grep -Fq "destination=$autoload_eval" "$autoload_out" &&
   [ ! -e "$WORK/config-must-not-execute" ]; then
  _pass "local config enables collection without executing shell syntax"
else
  _fail "local config autoload failed (exit $rc)"
fi
explicit_out="$WORK/explicit-doctor.txt"
PLX_EVAL_DIR="$explicit_eval" "$PLUGIN_ROOT/bin/plx-eval" doctor > "$explicit_out" 2>&1
rc=$?
if [ "$rc" -eq 0 ] && grep -Fq "destination=$explicit_eval" "$explicit_out"; then
  _pass "explicit PLX_EVAL_DIR overrides local config"
else
  _fail "explicit PLX_EVAL_DIR precedence failed (exit $rc)"
fi
rm "$XDG_CONFIG_HOME/parallax/env"

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

# --------------------------------------------------------------------------- #
# Evaluation provenance recorder (model-free, hermetic)
# --------------------------------------------------------------------------- #

_head "plx-eval disabled no-op and doctor"
eval_probe="$WORK/eval-disabled"
mkdir -p "$eval_probe"
run_file="$eval_probe/run-marker"
task_body="SECRET_TASK_BODY_SHOULD_NOT_APPEAR"
printf '%s\n' "$task_body" > "$eval_probe/task.md"
shape_body="Sizing: 1 worker (grok, medium)"
printf '%s\n' "$shape_body" > "$eval_probe/shape.txt"
# Ambient must stay unset for this case.
unset PLX_EVAL_DIR || true
"$PLUGIN_ROOT/bin/plx-eval" begin --repo "$REPO" --pipeline dev --host unknown \
  --run-file "$run_file" --task-file "$eval_probe/task.md" \
  --shape-file "$eval_probe/shape.txt" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 0 ] && grep -qx disabled "$run_file"; then
  _pass "disabled begin writes sentinel and exits 0"
else
  _fail "disabled begin failed (exit $rc)"
fi
if [ ! -d "$eval_probe/records" ] && [ -z "$(find "$eval_probe" -type d -name '20*' 2>/dev/null)" ]; then
  _pass "disabled begin creates no run directory"
else
  _fail "disabled begin wrote unexpected records"
fi
doctor_out="$eval_probe/doctor.txt"
"$PLUGIN_ROOT/bin/plx-eval" doctor > "$doctor_out" 2>&1
rc=$?
if [ "$rc" -eq 0 ] && grep -qi 'disabled' "$doctor_out"; then
  _pass "doctor reports disabled when PLX_EVAL_DIR unset"
else
  _fail "doctor disabled path failed (exit $rc)"
fi

# Engine with collection disabled: snapshot plausible eval artifacts around the
# prompt/work directory before and after; none may appear.
count_eval_artifacts() {
  # Count .plx-eval-run markers, run.json, and lane JSON under given roots.
  local root n=0
  for root in "$@"; do
    [ -d "$root" ] || continue
    n=$((n + $(find "$root" \( -name '.plx-eval-run' -o -name 'run.json' -o -path '*/lanes/*.json' \) 2>/dev/null | wc -l | tr -d ' ')))
  done
  printf '%s' "$n"
}
disabled_before="$(count_eval_artifacts "$WORK" "$(dirname "$fake_prompt")")"
PATH="$fake_bin:$PATH" env -u PLX_EVAL_DIR \
  "$PLUGIN_ROOT/bin/plx-engine" --engine grok --mode ro --repo "$REPO" \
  --prompt-file "$fake_prompt" --out "$fake_out" --log "$fake_log" >/dev/null
rc=$?
disabled_after="$(count_eval_artifacts "$WORK" "$(dirname "$fake_prompt")")"
if [ "$rc" -eq 0 ] && [ "$disabled_before" = "$disabled_after" ]; then
  _pass "disabled engine path leaves no eval files"
else
  _fail "disabled engine wrote eval files or failed (exit $rc; before=$disabled_before after=$disabled_after)"
fi

# The wrapper must defer enablement to plx-eval so file configuration also
# activates implicit standalone envelopes.
config_eval="$WORK/eval-config-implicit"
mkdir -p "$config_eval" "$XDG_CONFIG_HOME/parallax"
printf '%s\n' "PLX_EVAL_DIR=$config_eval" > "$XDG_CONFIG_HOME/parallax/env"
PATH="$fake_bin:$PATH" env -u PLX_EVAL_DIR \
  "$PLUGIN_ROOT/bin/plx-engine" --engine grok --mode ro --repo "$REPO" \
  --prompt-file "$fake_prompt" --out "$fake_out" --log "$fake_log" >/dev/null
rc=$?
config_runs="$(find "$config_eval" -name run.json | wc -l | tr -d ' ')"
config_lanes="$(find "$config_eval" -path '*/lanes/*.json' | wc -l | tr -d ' ')"
if [ "$rc" -eq 0 ] && [ "$config_runs" = 1 ] && [ "$config_lanes" = 1 ]; then
  _pass "local config activates implicit standalone recording"
else
  _fail "local config implicit recording failed (exit $rc runs=$config_runs lanes=$config_lanes)"
fi
rm "$XDG_CONFIG_HOME/parallax/env"

_head "plx-eval grouped begin + concurrent lanes + finish"
eval_dir="$WORK/eval-enabled"
mkdir -p "$eval_dir"
group_tmp="$WORK/group-tmp"
mkdir -p "$group_tmp"
printf '%s\n' "$task_body" > "$group_tmp/task.md"
printf '%s\n' "$shape_body" > "$group_tmp/shape.txt"
printf '%s\n' 'lane prompt SECRET_PROMPT_BODY' > "$group_tmp/lane-a.md"
printf '%s\n' 'lane prompt SECRET_PROMPT_BODY' > "$group_tmp/lane-b.md"
group_run="$group_tmp/.plx-eval-run"

PLX_EVAL_DIR="$eval_dir" "$PLUGIN_ROOT/bin/plx-eval" begin \
  --repo "$REPO" --pipeline dev --host claude \
  --run-file "$group_run" \
  --task-file "$group_tmp/task.md" \
  --shape-file "$group_tmp/shape.txt" >/dev/null
rc=$?
if [ "$rc" -eq 0 ] && grep -q '^run_dir=' "$group_run"; then
  _pass "enabled begin writes run marker"
else
  _fail "enabled begin failed (exit $rc)"
fi

# Two concurrent fake-engine lanes (grouped via prompt-dir marker).
PATH="$fake_bin:$PATH" PLX_EVAL_DIR="$eval_dir" \
  "$PLUGIN_ROOT/bin/plx-engine" --engine grok --mode ro --repo "$REPO" \
  --prompt-file "$group_tmp/lane-a.md" --rubric worker \
  --out "$group_tmp/out-a.md" --log "$group_tmp/log-a.log" >/dev/null &
pid_a=$!
PATH="$fake_bin:$PATH" PLX_EVAL_DIR="$eval_dir" \
  "$PLUGIN_ROOT/bin/plx-engine" --engine codex --mode ro --repo "$REPO" \
  --prompt-file "$group_tmp/lane-b.md" --rubric reviewer-correctness \
  --out "$group_tmp/out-b.md" --log "$group_tmp/log-b.log" >/dev/null &
pid_b=$!
wait "$pid_a"
rc_a=$?
wait "$pid_b"
rc_b=$?
if [ "$rc_a" -eq 0 ] && [ "$rc_b" -eq 0 ]; then
  _pass "concurrent grouped lanes exit 0"
else
  _fail "concurrent grouped lanes failed (a=$rc_a b=$rc_b)"
fi

PLX_EVAL_DIR="$eval_dir" "$PLUGIN_ROOT/bin/plx-eval" finish \
  --repo "$REPO" --run-file "$group_run" \
  --outcome pass --verification pass >/dev/null
rc=$?
run_dirs="$(find "$eval_dir" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
lane_files="$(find "$eval_dir" -path '*/lanes/*.json' | wc -l | tr -d ' ')"
run_json="$(find "$eval_dir" -name run.json | head -1)"
if [ "$rc" -eq 0 ] && [ "$run_dirs" = "1" ] && [ "$lane_files" = "2" ] && [ -n "$run_json" ]; then
  _pass "grouped finish: one envelope, two lane files"
else
  _fail "grouped finish shape wrong (rc=$rc runs=$run_dirs lanes=$lane_files)"
fi
if python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$run_json" 2>/dev/null; then
  _pass "run.json parses"
else
  _fail "run.json invalid"
fi
# Privacy: no known bodies in any record.
privacy_hit=0
if grep -RFq "$task_body" "$eval_dir" 2>/dev/null; then privacy_hit=1; fi
if grep -RFq "SECRET_PROMPT_BODY" "$eval_dir" 2>/dev/null; then privacy_hit=1; fi
if [ "$privacy_hit" -eq 0 ]; then
  _pass "records omit task/prompt bodies"
else
  _fail "records leaked task or prompt body"
fi
# Hashes present
if python3 -c '
import json,sys
r=json.load(open(sys.argv[1]))
assert r.get("schema_version")==1
assert r.get("task_sha256")
assert r.get("status")=="complete"
assert r.get("lane_count")==2
assert r.get("pipeline")=="dev"
' "$run_json" 2>/dev/null; then
  _pass "run.json has schema v1 hashes and lane_count"
else
  _fail "run.json missing required metadata"
fi

_head "plx-eval implicit standalone + failed lane + unwritable dest"
# Implicit standalone: no marker next to prompt
standalone_prompt="$WORK/standalone-prompt.md"
printf '%s\n' 'standalone SECRET_STANDALONE_PROMPT' > "$standalone_prompt"
standalone_eval="$WORK/eval-standalone"
mkdir -p "$standalone_eval"
PATH="$fake_bin:$PATH" PLX_EVAL_DIR="$standalone_eval" \
  "$PLUGIN_ROOT/bin/plx-engine" --engine grok --mode ro --repo "$REPO" \
  --prompt-file "$standalone_prompt" \
  --out "$WORK/standalone-out.md" --log "$WORK/standalone.log" >/dev/null
rc=$?
s_runs="$(find "$standalone_eval" -name run.json | wc -l | tr -d ' ')"
s_lanes="$(find "$standalone_eval" -path '*/lanes/*.json' | wc -l | tr -d ' ')"
s_run="$(find "$standalone_eval" -name run.json | head -1)"
if [ "$rc" -eq 0 ] && [ "$s_runs" = "1" ] && [ "$s_lanes" = "1" ]; then
  _pass "ungrouped engine creates one implicit standalone run"
else
  _fail "implicit standalone wrong (rc=$rc runs=$s_runs lanes=$s_lanes)"
fi
if python3 -c '
import json,sys
r=json.load(open(sys.argv[1]))
assert r.get("pipeline")=="standalone-lane"
assert r.get("status")=="complete"
assert r.get("outcome")=="pass"
' "$s_run" 2>/dev/null; then
  _pass "implicit run closed with pass"
else
  _fail "implicit run not closed correctly"
fi
if ! grep -RFq "SECRET_STANDALONE_PROMPT" "$standalone_eval" 2>/dev/null; then
  _pass "standalone records omit prompt body"
else
  _fail "standalone records leaked prompt body"
fi

# Failed fake engine preserves exit code and still records
printf '%s\n' '#!/usr/bin/env bash' \
  'echo fail-noise >&2' \
  'exit 1' \
  > "$fake_bin/grok"
chmod +x "$fake_bin/grok"
fail_eval="$WORK/eval-fail"
mkdir -p "$fail_eval"
fail_prompt="$WORK/fail-prompt.md"
printf '%s\n' 'fail me SECRET_FAIL_OUTPUT_BODY' > "$fail_prompt"
PATH="$fake_bin:$PATH" PLX_EVAL_DIR="$fail_eval" \
  "$PLUGIN_ROOT/bin/plx-engine" --engine grok --mode ro --repo "$REPO" \
  --prompt-file "$fail_prompt" \
  --out "$WORK/fail-out.md" --log "$WORK/fail.log" >/dev/null 2>"$WORK/fail-stderr.txt"
fail_rc=$?
if [ "$fail_rc" -eq 1 ]; then
  _pass "failed engine preserves exit code 1"
else
  _fail "failed engine exit was $fail_rc (expected 1)"
fi
fail_lane="$(find "$fail_eval" -path '*/lanes/*.json' | head -1)"
if [ -n "$fail_lane" ] && python3 -c '
import json,sys
l=json.load(open(sys.argv[1]))
assert l.get("exit_code")==1
' "$fail_lane" 2>/dev/null; then
  _pass "failed lane recorded with exit_code 1"
else
  _fail "failed lane not recorded correctly"
fi

# Restore successful fake grok for any later tests
printf '%s\n' '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' "$@" > "$PLX_GROK_ARGS_FILE"' \
  'printf '\''{"text":"OK","stopReason":"EndTurn","sessionId":""}\n'\''' \
  > "$fake_bin/grok"
chmod +x "$fake_bin/grok"

# Unwritable / invalid destination must not change a successful engine exit
bad_eval="$WORK/eval-bad-dest"
# Create a file where a directory is required — not a writable dir
printf 'not-a-dir\n' > "$bad_eval"
PATH="$fake_bin:$PATH" PLX_EVAL_DIR="$bad_eval" PLX_GROK_ARGS_FILE="$fake_args" \
  "$PLUGIN_ROOT/bin/plx-engine" --engine grok --mode ro --repo "$REPO" \
  --prompt-file "$fake_prompt" --out "$fake_out" --log "$fake_log" >/dev/null 2>"$WORK/bad-dest-stderr.txt"
rc=$?
if [ "$rc" -eq 0 ]; then
  _pass "unwritable/invalid eval dest does not change engine exit 0"
else
  _fail "bad eval dest altered engine exit to $rc"
fi

# doctor on valid enabled destination
doctor_ok="$WORK/doctor-ok.txt"
PLX_EVAL_DIR="$eval_dir" "$PLUGIN_ROOT/bin/plx-eval" doctor > "$doctor_ok" 2>&1
rc=$?
if [ "$rc" -eq 0 ] && grep -qi 'ok' "$doctor_ok"; then
  _pass "doctor validates writable destination"
else
  _fail "doctor enabled path failed (exit $rc)"
fi

# Forged marker pointing outside PLX_EVAL_DIR must not write anywhere and must
# preserve the engine exit code.
_head "plx-eval forged marker outside eval root is ignored"
forged_eval_root="$WORK/eval-legit-root"
forged_outside="$WORK/eval-forged-outside"
forged_prompt_dir="$WORK/forged-prompt-dir"
mkdir -p "$forged_eval_root" "$forged_prompt_dir"
forged_run_id="20260101T000000Z-forged0001"
mkdir -p "$forged_outside/$forged_run_id/lanes"
python3 -c '
import json, sys
repo, path, run_id = sys.argv[1], sys.argv[2], sys.argv[3]
json.dump({
  "schema_version": 1,
  "run_id": run_id,
  "status": "incomplete",
  "target_path": repo,
  "pipeline": "dev",
  "lane_count": 0,
}, open(path, "w"), indent=2)
' "$REPO" "$forged_outside/$forged_run_id/run.json" "$forged_run_id"
printf 'run_dir=%s\n' "$forged_outside/$forged_run_id" > "$forged_prompt_dir/.plx-eval-run"
printf '%s\n' 'forged marker prompt' > "$forged_prompt_dir/lane.md"
forged_out="$forged_prompt_dir/out.md"
forged_log="$forged_prompt_dir/log.log"
outside_before="$(find "$forged_outside" -type f 2>/dev/null | wc -l | tr -d ' ')"
legit_before="$(find "$forged_eval_root" -type f 2>/dev/null | wc -l | tr -d ' ')"
PATH="$fake_bin:$PATH" PLX_EVAL_DIR="$forged_eval_root" \
  "$PLUGIN_ROOT/bin/plx-engine" --engine grok --mode ro --repo "$REPO" \
  --prompt-file "$forged_prompt_dir/lane.md" \
  --out "$forged_out" --log "$forged_log" >/dev/null
rc=$?
outside_after="$(find "$forged_outside" -type f 2>/dev/null | wc -l | tr -d ' ')"
legit_after="$(find "$forged_eval_root" -type f 2>/dev/null | wc -l | tr -d ' ')"
outside_lanes="$(find "$forged_outside" -path '*/lanes/*.json' 2>/dev/null | wc -l | tr -d ' ')"
if [ "$rc" -eq 0 ] && [ "$outside_before" = "$outside_after" ] \
  && [ "$legit_before" = "$legit_after" ] && [ "$outside_lanes" = "0" ]; then
  _pass "forged outside marker writes nowhere and keeps exit 0"
else
  _fail "forged marker mishandled (rc=$rc outside $outside_before->$outside_after legit $legit_before->$legit_after lanes=$outside_lanes)"
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
