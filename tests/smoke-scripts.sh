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
for rubric in simplify-reuse simplify-simplification simplify-efficiency simplify-altitude; do
  if "$PLUGIN_ROOT/bin/plx-engine" --print-rubric "$rubric" 2>/dev/null |
     grep -Fq 'Parallax Simplify rubric'; then
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

_head "plx-engine pins Grok 4.6 to medium and passes other model overrides"
fake_bin="$WORK/fake-bin"
fake_args="$WORK/grok-args.txt"
fake_prompt="$WORK/grok-prompt.md"
fake_out="$WORK/grok-out.md"
fake_log="$WORK/grok.log"
mkdir -p "$fake_bin"
printf '%s\n' '#!/usr/bin/env bash' \
  '# Fake Grok CLI — records argv and returns one successful headless envelope.' \
  'printf '\''%s\n'\'' "$@" > "$PLX_GROK_ARGS_FILE"' \
  'printf '\''{"text":"OK","stopReason":"end_turn","sessionId":""}\n'\''' \
  > "$fake_bin/grok"
chmod +x "$fake_bin/grok"
printf '%s\n' 'reply OK' > "$fake_prompt"

incomplete_plugin="$WORK/incomplete-plugin"
cp -R "$PLUGIN_ROOT" "$incomplete_plugin"
awk '{ print; if ($0 == "EVAL_ARMED=1") print "exit 0" }' \
  "$PLUGIN_ROOT/bin/plx-engine" > "$WORK/plx-engine-incomplete"
mv "$WORK/plx-engine-incomplete" "$incomplete_plugin/bin/plx-engine"
chmod +x "$incomplete_plugin/bin/plx-engine"
PATH="$fake_bin:$PATH" PLX_GROK_ARGS_FILE="$fake_args" \
  "$incomplete_plugin/bin/plx-engine" --engine grok --mode ro --repo "$REPO" \
  --prompt-file "$fake_prompt" --out "$fake_out" --log "$fake_log" \
  > /dev/null 2> "$WORK/incomplete-error.txt"
rc=$?
if [ "$rc" -eq 1 ] && grep -Fq 'execution ended before output delivery completed' \
   "$WORK/incomplete-error.txt"; then
  _pass "plx-engine rejects an armed but incomplete zero-status exit"
else
  _fail "plx-engine incomplete execution expected exit 1, got $rc"
fi

PATH="$fake_bin:$PATH" PLX_GROK_ARGS_FILE="$fake_args" \
  "$PLUGIN_ROOT/bin/plx-engine" --engine grok --mode ro --repo "$REPO" \
  --prompt-file "$fake_prompt" --out "$fake_out" --log "$fake_log" >/dev/null
rc=$?
if [ "$rc" -eq 0 ]; then _pass "Grok default invocation exits 0"; else _fail "Grok default invocation exits $rc"; fi
assert_contains "grok-4.6" "$fake_args" "Grok model is grok-4.6"
assert_contains "medium" "$fake_args" "Grok effort defaults to medium"
for flag in --no-auto-update --no-plan --no-subagents --no-memory --no-alt-screen; do
  assert_contains "$flag" "$fake_args" "Grok receives $flag"
done
assert_contains "read-only" "$fake_args" "Grok ro uses read-only sandbox"

printf '%s\n' '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' "$@" > "$PLX_GROK_ARGS_FILE"' \
  'printf '\''{"text":"should not pass","stopReason":"cancelled","sessionId":""}\n'\''' \
  > "$fake_bin/grok"
chmod +x "$fake_bin/grok"
PATH="$fake_bin:$PATH" PLX_GROK_ARGS_FILE="$fake_args" \
  "$PLUGIN_ROOT/bin/plx-engine" --engine grok --mode ro --repo "$REPO" \
  --prompt-file "$fake_prompt" --out "$fake_out" --log "$fake_log" \
  >/dev/null 2> "$WORK/grok-cancelled.txt"
rc=$?
if [ "$rc" -eq 1 ] && grep -Fq 'grok turn was cancelled' "$WORK/grok-cancelled.txt"; then
  _pass "Grok lowercase cancelled stop reason fails closed"
else
  _fail "Grok lowercase cancelled stop reason expected exit 1, got $rc"
fi
printf '%s\n' '#!/usr/bin/env bash' \
  'printf '\''%s\n'\'' "$@" > "$PLX_GROK_ARGS_FILE"' \
  'printf '\''{"text":"OK","stopReason":"end_turn","sessionId":""}\n'\''' \
  > "$fake_bin/grok"
chmod +x "$fake_bin/grok"

for effort in low high xhigh; do
  PATH="$fake_bin:$PATH" PLX_GROK_ARGS_FILE="$fake_args" \
    "$PLUGIN_ROOT/bin/plx-engine" --engine grok --mode rw --repo "$REPO" \
    --prompt-file "$fake_prompt" --model grok-4.6 --effort "$effort" \
    --out "$fake_out" --log "$fake_log" >/dev/null
  rc=$?
  if [ "$rc" -eq 0 ] && grep -qx "medium" "$fake_args"; then
    _pass "Grok 4.6 normalizes explicit $effort effort to medium"
  else
    _fail "Grok 4.6 did not normalize explicit $effort effort to medium"
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

_head "plx-engine runs Devin as explicit full access and validates terminal ATIF"
fake_devin_args="$WORK/devin-args.txt"
fake_devin_prompt="$WORK/devin-prompt.md"
fake_devin_config="$WORK/devin-config.json"
fake_devin_sandbox_env="$WORK/devin-sandbox-env.txt"
fake_devin_child="$WORK/devin-child.pid"
fake_devin_ready="$WORK/devin-ready"
mkdir -p "$REPO/nested/.devin/rules" "$REPO/nested/.devin/skills/local" \
  "$REPO/ignored"
printf '%s\n' 'nested claude guidance' > "$REPO/nested/CLAUDE.md"
printf '%s\n' 'native Devin rule' > "$REPO/nested/.devin/rules/native.md"
printf '%s\n' 'native Devin skill' > "$REPO/nested/.devin/skills/local/SKILL.md"
printf '%s\n' 'ignored agent guidance' > "$REPO/ignored/AGENTS.md"
printf '%s\n' '/ignored/' >> "$REPO/.git/info/exclude"
printf '%s\n' '#!/usr/bin/env bash' \
  '# Fake Devin CLI — records calls and emits selected ATIF terminal shapes.' \
  'set -u' \
  'printf '\''CALL\n'\'' >> "$PLX_DEVIN_ARGS_FILE"' \
  'printf '\''%s\n'\'' "$@" >> "$PLX_DEVIN_ARGS_FILE"' \
  'is_auth=0; config=""; prompt=""; export_file=""' \
  'while [ "$#" -gt 0 ]; do' \
  '  case "$1" in' \
  '    auth) is_auth=1; shift ;;' \
  '    --config) config="$2"; shift 2 ;;' \
  '    --prompt-file) prompt="$2"; shift 2 ;;' \
  '    --export) export_file="$2"; shift 2 ;;' \
  '    *) shift ;;' \
  '  esac' \
  'done' \
  'if [ "$is_auth" -eq 1 ]; then' \
  '  if [ "${PLX_DEVIN_FAKE_CASE:-success}" = auth-fail ]; then' \
  '    printf '\''Not logged in; run devin auth login\n'\'' >&2; exit 1' \
  '  fi' \
  '  exit 0' \
  'fi' \
  'cp "$config" "$PLX_DEVIN_CONFIG_FILE"' \
  'cp "$prompt" "$PLX_DEVIN_PROMPT_FILE"' \
  'printf '\''%s\n'\'' "${DEVIN_SANDBOX-unset}" > "$PLX_DEVIN_SANDBOX_ENV_FILE"' \
  'printf '\''PROGRESS_STDOUT\n'\''' \
  'printf '\''PROGRESS_STDERR\n'\'' >&2' \
  'case "${PLX_DEVIN_FAKE_CASE:-success}" in' \
  '  diagnostic)' \
  '    cat "$PLX_DEVIN_DIAGNOSTIC_STDERR" >&2' \
  '    cat "$PLX_DEVIN_DIAGNOSTIC_STDOUT"' \
  '    printf '\''%s\n'\'' '\''{"schema_version":"ATIF-v1.7","steps":[{"source":"agent","message":"FINAL_OK"}]} '\'' > "$export_file"' \
  '    exit "$PLX_DEVIN_NATIVE_RC" ;;' \
  '  success)' \
  '    printf '\''%s\n'\'' '\''{"schema_version":"ATIF-v1.7","steps":[{"source":"agent","message":"INTERMEDIATE","reasoning_content":"SECRET","tool_calls":[{"function_name":"read"}]},{"source":"agent","message":"FINAL_OK","reasoning_content":"PRIVATE","tool_calls":[]}]} '\'' > "$export_file"' \
  '    exit 0 ;;' \
  '  success-auth-text)' \
  '    printf '\''%s\n'\'' '\''{"schema_version":"ATIF-v1.7","steps":[{"source":"agent","message":"Documentation may mention devin auth login","tool_calls":[]}]} '\'' > "$export_file"' \
  '    exit 0 ;;' \
  '  incomplete)' \
  '    printf '\''%s\n'\'' '\''{"schema_version":"ATIF-v1.7","steps":[{"source":"agent","message":"","tool_calls":[{"function_name":"write"}],"observation":{"results":[{"content":"Write access denied"}]}}]} '\'' > "$export_file"' \
  '    exit 0 ;;' \
  '  malformed) printf '\''{\n'\'' > "$export_file"; exit 0 ;;' \
  '  native-fail)' \
  '    printf '\''%s\n'\'' '\''{"schema_version":"ATIF-v1.7","steps":[{"source":"agent","message":"MUST_NOT_PASS","tool_calls":[]}]} '\'' > "$export_file"' \
  '    exit 7 ;;' \
  '  native-auth-fail)' \
  '    printf '\''Not logged in; run devin auth login\n'\'' >&2; exit 7 ;;' \
  '  interrupt)' \
  '    trap '\'''\'' TERM' \
  '    sleep 60 &' \
  '    printf '\''%s\n'\'' "$!" > "$PLX_DEVIN_CHILD_FILE"' \
  '    printf '\''ready\n'\'' > "$PLX_DEVIN_READY_FILE"' \
  '    wait ;;' \
  'esac' \
  'exit 9' \
  > "$fake_bin/devin"
chmod +x "$fake_bin/devin"

: > "$fake_devin_args"
PATH="$fake_bin:$PATH" PLX_DEVIN_ARGS_FILE="$fake_devin_args" \
  PLX_DEVIN_PROMPT_FILE="$fake_devin_prompt" \
  PLX_DEVIN_CONFIG_FILE="$fake_devin_config" \
  PLX_DEVIN_SANDBOX_ENV_FILE="$fake_devin_sandbox_env" \
  DEVIN_SANDBOX=1 \
  "$PLUGIN_ROOT/bin/plx-engine" --engine devin --mode full-access --repo "$REPO" \
  --prompt-file "$fake_prompt" --out "$fake_out" --log "$fake_log" >/dev/null
rc=$?
if [ "$rc" -eq 0 ] && [ "$(cat "$fake_out")" = FINAL_OK ]; then
  _pass "Devin default invocation emits only the terminal agent response"
else
  _fail "Devin default invocation expected FINAL_OK, got exit $rc"
fi
assert_contains "swe-2-high" "$fake_devin_args" "Devin model defaults to SWE-2 High"
assert_contains "dangerous" "$fake_devin_args" "Devin uses documented full-access permission mode"
assert_contains "unset" "$fake_devin_sandbox_env" "Devin ignores inherited DEVIN_SANDBOX"
if grep -qx -- '--sandbox' "$fake_devin_args" ||
   grep -qxE -- '-r|--resume|-c|--continue' "$fake_devin_args" ||
   grep -qx -- '--respect-workspace-trust' "$fake_devin_args"; then
  _fail "Devin invocation includes sandbox, resume, or trust-bypass flags"
else
  _pass "Devin invocation has no sandbox, resume, or trust-bypass flags"
fi
if python3 - "$fake_prompt" "$fake_devin_prompt" <<'PY'
from pathlib import Path
import sys
source, effective = (Path(path).read_bytes() for path in sys.argv[1:])
assert effective.startswith(source)
PY
then
  _pass "Devin preserves the prompt bytes before its runtime boundary"
else
  _fail "Devin prompt prefix fidelity drift"
fi
for guidance in nested/CLAUDE.md nested/.devin/rules/native.md \
  nested/.devin/skills/local/SKILL.md ignored/AGENTS.md; do
  assert_contains "$guidance" "$fake_devin_prompt" \
    "Devin effective prompt lists $guidance"
done
assert_contains "Devin has full host access" "$fake_devin_prompt" \
  "Devin effective prompt states the transport boundary"
if grep -Fq '"subagents_enabled": false' "$fake_devin_config" &&
   grep -Fq '"auto_update": false' "$fake_devin_config" &&
   grep -Fq '"claude": false' "$fake_devin_config"; then
  _pass "Devin generated config disables supported ambient behavior"
else
  _fail "Devin generated config does not minimize supported ambient behavior"
fi
assert_contains "PROGRESS_STDOUT" "$fake_log" "Devin print progress stays in the log"
if grep -Fq 'INTERMEDIATE' "$fake_out" || grep -Fq 'PRIVATE' "$fake_out"; then
  _fail "Devin output leaked intermediate or reasoning content"
else
  _pass "Devin output excludes intermediate and reasoning content"
fi

PATH="$fake_bin:$PATH" PLX_DEVIN_ARGS_FILE="$fake_devin_args" \
  PLX_DEVIN_PROMPT_FILE="$fake_devin_prompt" \
  PLX_DEVIN_CONFIG_FILE="$fake_devin_config" \
  PLX_DEVIN_SANDBOX_ENV_FILE="$fake_devin_sandbox_env" \
  "$PLUGIN_ROOT/bin/plx-engine" --engine devin --mode full-access --repo "$REPO" \
  --prompt-file "$fake_prompt" --model custom-devin-model \
  --out "$fake_out" --log "$fake_log" >/dev/null
rc=$?
if [ "$rc" -eq 0 ] && grep -qx custom-devin-model "$fake_devin_args"; then
  _pass "Devin exact model overrides pass through"
else
  _fail "Devin exact model override failed (exit $rc)"
fi

PATH="$fake_bin:$PATH" PLX_DEVIN_FAKE_CASE=success-auth-text \
  PLX_DEVIN_ARGS_FILE="$fake_devin_args" \
  PLX_DEVIN_PROMPT_FILE="$fake_devin_prompt" \
  PLX_DEVIN_CONFIG_FILE="$fake_devin_config" \
  PLX_DEVIN_SANDBOX_ENV_FILE="$fake_devin_sandbox_env" \
  "$PLUGIN_ROOT/bin/plx-engine" --engine devin --mode full-access --repo "$REPO" \
  --prompt-file "$fake_prompt" --out "$fake_out" --log "$fake_log" >/dev/null
rc=$?
if [ "$rc" -eq 0 ] && grep -Fq 'devin auth login' "$fake_out"; then
  _pass "Devin successful final text cannot be misclassified as an auth failure"
else
  _fail "Devin successful auth-related answer was misclassified (exit $rc)"
fi

"$PLUGIN_ROOT/bin/plx-engine" --engine devin --mode full-access --repo "$REPO" \
  --prompt-file "$fake_prompt" --effort high --out "$fake_out" --log "$fake_log" \
  >/dev/null 2> "$WORK/devin-effort-error.txt"
rc=$?
if [ "$rc" -eq 2 ] && grep -Fq 'does not support --effort' "$WORK/devin-effort-error.txt"; then
  _pass "Devin rejects unsupported effort values"
else
  _fail "Devin effort rejection expected exit 2, got $rc"
fi

for invalid_pair in 'devin ro' 'grok full-access'; do
  set -- $invalid_pair
  "$PLUGIN_ROOT/bin/plx-engine" --engine "$1" --mode "$2" --repo "$REPO" \
    --prompt-file "$fake_prompt" --out "$fake_out" --log "$fake_log" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 2 ]; then
    _pass "$1 rejects mode $2"
  else
    _fail "$1 mode $2 expected exit 2, got $rc"
  fi
done

_head "Devin retry classification is narrow and never replays inside the wrapper"
python3 - "$WORK" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
header = ("Error: Agent error: Client error: Protocol error (invalid_argument): "
          "an internal error occurred (trace ID: b52ca2c46092fccc753fe7eb165cb5f2): ")
detail = {"cognition.ai/errorKind": "internal", "cognition.ai/retryable": True}
diagnostic = header + json.dumps(detail, indent=2) + "\n"
cases = [
    ("retryable", diagnostic, "", 1, 4),
    ("retryable-seven", diagnostic, "", 7, 4),
    ("double-diagnostic", diagnostic + diagnostic, "", 1, 4),
    ("stdout-quote", "", diagnostic, 1, 1),
    ("stdout-auth-quote", diagnostic, "Documentation: devin auth login\n", 1, 4),
    ("stdout-auth-only", "", "Documentation: devin auth login\n", 1, 1),
    ("success-quote", diagnostic, "", 0, 0),
    ("signal", diagnostic, "", 143, 1),
    ("auth-priority", "Not logged in; run devin auth login\n" + diagnostic, "", 7, 3),
    ("trailing-error", diagnostic + "Error: another failure\n", "", 1, 1),
    ("embedded-quote", "Quoted example: " + diagnostic, "", 1, 1),
    ("malformed-detail", header + "{bad json}\n", "", 1, 1),
    ("array-detail", header + "[]\n", "", 1, 1),
    ("scalar-detail", header + "true\n", "", 1, 1),
    ("generic-retryable", json.dumps(detail), "", 1, 1),
    ("wrong-protocol", diagnostic.replace("invalid_argument", "permission_denied"), "", 1, 1),
]
for value in (False, "true", 1, None):
    altered = dict(detail, **{"cognition.ai/retryable": value})
    cases.append(("value-" + str(value), header + json.dumps(altered), "", 1, 1))
for name, altered in (("missing", {"cognition.ai/errorKind": "internal"}),
                      ("quota", dict(detail, **{"cognition.ai/errorKind": "resource_exhausted"})),
                      ("unavailable", dict(detail, **{"cognition.ai/errorKind": "unavailable"})),
                      ("wrong-kind", dict(detail, **{"cognition.ai/errorKind": "auth"}))):
    cases.append((name, header + json.dumps(altered), "", 1, 1))
with (root / "devin-diagnostic-cases").open("w") as manifest:
    for name, stderr, stdout, native_rc, expected in cases:
        (root / (name + ".stderr")).write_text(stderr)
        (root / (name + ".stdout")).write_text(stdout)
        manifest.write(f"{name} {native_rc} {expected}\n")
PY
while read -r diagnostic_case native_rc expected; do
  printf '%s\n' STALE > "$fake_out"
  : > "$fake_devin_args"
  PATH="$fake_bin:$PATH" PLX_DEVIN_FAKE_CASE=diagnostic \
    PLX_DEVIN_DIAGNOSTIC_STDERR="$WORK/$diagnostic_case.stderr" \
    PLX_DEVIN_DIAGNOSTIC_STDOUT="$WORK/$diagnostic_case.stdout" \
    PLX_DEVIN_NATIVE_RC="$native_rc" \
    PLX_DEVIN_ARGS_FILE="$fake_devin_args" \
    PLX_DEVIN_PROMPT_FILE="$fake_devin_prompt" \
    PLX_DEVIN_CONFIG_FILE="$fake_devin_config" \
    PLX_DEVIN_SANDBOX_ENV_FILE="$fake_devin_sandbox_env" \
    "$PLUGIN_ROOT/bin/plx-engine" --engine devin --mode full-access --repo "$REPO" \
    --prompt-file "$fake_prompt" --out "$fake_out" --log "$fake_log" \
    > /dev/null 2> "$WORK/devin-diagnostic-error.txt"
  rc=$?
  if [ "$rc" -eq "$expected" ] && [ "$(grep -c '^CALL$' "$fake_devin_args")" -eq 2 ] &&
     { { [ "$rc" -eq 0 ] && grep -qx FINAL_OK "$fake_out"; } ||
       { [ "$rc" -ne 0 ] && [ ! -s "$fake_out" ]; }; }; then
    _pass "Devin $diagnostic_case classifies exit $expected with one invocation and clean output"
  else
    _fail "Devin $diagnostic_case expected exit $expected with one invocation, got $rc"
  fi
done < "$WORK/devin-diagnostic-cases"

for fake_case in incomplete malformed native-fail; do
  printf '%s\n' STALE > "$fake_out"
  PATH="$fake_bin:$PATH" PLX_DEVIN_FAKE_CASE="$fake_case" \
    PLX_DEVIN_ARGS_FILE="$fake_devin_args" \
    PLX_DEVIN_PROMPT_FILE="$fake_devin_prompt" \
    PLX_DEVIN_CONFIG_FILE="$fake_devin_config" \
    PLX_DEVIN_SANDBOX_ENV_FILE="$fake_devin_sandbox_env" \
    "$PLUGIN_ROOT/bin/plx-engine" --engine devin --mode full-access --repo "$REPO" \
    --prompt-file "$fake_prompt" --out "$fake_out" --log "$fake_log" \
    >/dev/null 2> "$WORK/devin-$fake_case-error.txt"
  rc=$?
  if [ "$rc" -eq 1 ] && [ ! -s "$fake_out" ]; then
    _pass "Devin $fake_case fails closed and clears stale output"
  else
    _fail "Devin $fake_case expected empty output and exit 1, got $rc"
  fi
done

PATH="$fake_bin:$PATH" PLX_DEVIN_FAKE_CASE=auth-fail \
  PLX_DEVIN_ARGS_FILE="$fake_devin_args" \
  PLX_DEVIN_PROMPT_FILE="$fake_devin_prompt" \
  PLX_DEVIN_CONFIG_FILE="$fake_devin_config" \
  PLX_DEVIN_SANDBOX_ENV_FILE="$fake_devin_sandbox_env" \
  "$PLUGIN_ROOT/bin/plx-engine" --engine devin --mode full-access --repo "$REPO" \
  --prompt-file "$fake_prompt" --out "$fake_out" --log "$fake_log" \
  >/dev/null 2> "$WORK/devin-auth-error.txt"
rc=$?
if [ "$rc" -eq 3 ] && grep -Fq 'devin auth login' "$WORK/devin-auth-error.txt"; then
  _pass "Devin missing authentication exits 3 with recovery guidance"
else
  _fail "Devin auth failure expected exit 3, got $rc"
fi

PATH="$fake_bin:$PATH" PLX_DEVIN_FAKE_CASE=native-auth-fail \
  PLX_DEVIN_ARGS_FILE="$fake_devin_args" \
  PLX_DEVIN_PROMPT_FILE="$fake_devin_prompt" \
  PLX_DEVIN_CONFIG_FILE="$fake_devin_config" \
  PLX_DEVIN_SANDBOX_ENV_FILE="$fake_devin_sandbox_env" \
  "$PLUGIN_ROOT/bin/plx-engine" --engine devin --mode full-access --repo "$REPO" \
  --prompt-file "$fake_prompt" --out "$fake_out" --log "$fake_log" \
  >/dev/null 2> "$WORK/devin-native-auth-error.txt"
rc=$?
if [ "$rc" -eq 3 ]; then
  _pass "Devin failed native invocation classifies genuine auth diagnostics"
else
  _fail "Devin native auth failure expected exit 3, got $rc"
fi

rm -f "$fake_devin_ready" "$fake_devin_child"
PATH="$fake_bin:$PATH" PLX_DEVIN_FAKE_CASE=interrupt \
  PLX_DEVIN_ARGS_FILE="$fake_devin_args" \
  PLX_DEVIN_PROMPT_FILE="$fake_devin_prompt" \
  PLX_DEVIN_CONFIG_FILE="$fake_devin_config" \
  PLX_DEVIN_SANDBOX_ENV_FILE="$fake_devin_sandbox_env" \
  PLX_DEVIN_CHILD_FILE="$fake_devin_child" \
  PLX_DEVIN_READY_FILE="$fake_devin_ready" \
  "$PLUGIN_ROOT/bin/plx-engine" --engine devin --mode full-access --repo "$REPO" \
  --prompt-file "$fake_prompt" --out "$fake_out" --log "$fake_log" \
  >/dev/null 2> "$WORK/devin-interrupt-error.txt" &
devin_wrapper_pid=$!
tries=0
while [ ! -s "$fake_devin_ready" ] && [ "$tries" -lt 100 ]; do
  sleep 0.05
  tries=$((tries + 1))
done
if [ -s "$fake_devin_ready" ]; then
  kill -TERM "$devin_wrapper_pid"
fi
wait "$devin_wrapper_pid"
rc=$?
devin_child_pid="$(cat "$fake_devin_child" 2>/dev/null || true)"
if [ "$rc" -eq 1 ] && [ -n "$devin_child_pid" ] && \
   ! kill -0 "$devin_child_pid" 2>/dev/null && \
   grep -Fq 'process tree was stopped' "$WORK/devin-interrupt-error.txt"; then
  _pass "Devin interruption stops the owned process group without retry"
else
  _fail "Devin interruption left a child or returned the wrong status (exit $rc)"
  [ -z "$devin_child_pid" ] || kill -TERM "$devin_child_pid" 2>/dev/null || true
fi

PATH="/usr/bin:/bin" "$PLUGIN_ROOT/bin/plx-engine" \
  --engine devin --mode full-access --repo "$REPO" --prompt-file "$fake_prompt" \
  --out "$fake_out" --log "$fake_log" >/dev/null 2> "$WORK/devin-missing-error.txt"
rc=$?
if [ "$rc" -eq 1 ] && grep -Fq 'Devin CLI not found' "$WORK/devin-missing-error.txt"; then
  _pass "missing Devin CLI fails before invocation"
else
  _fail "missing Devin CLI expected exit 1, got $rc"
fi
rm "$REPO/nested/CLAUDE.md" "$REPO/ignored/AGENTS.md"

if "$PLUGIN_ROOT/bin/plx-engine" --print-rubric no-such-rubric >/dev/null 2>&1; then
  _fail "should reject unknown rubric"
else
  _pass "non-zero exit on unknown rubric"
fi

_head "plx-engine defaults Codex to GPT-6 Sol at medium effort"
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
assert_contains "gpt-6-sol" "$fake_codex_args" "Codex model defaults to GPT-6 Sol"
assert_contains "model_reasoning_effort=medium" "$fake_codex_args" "Codex effort defaults to medium"
assert_contains "approval_policy=never" "$fake_codex_args" "Codex headless approval policy is explicit"
assert_contains "workspace-write" "$fake_codex_args" "Codex rw uses workspace-write sandbox"

for retired_model in gpt-5.6 gpt-5.6-sol gpt-5.6-luna opus opus-5 claude-opus-5; do
  PATH="$fake_bin:$PATH" PLX_CODEX_ARGS_FILE="$fake_codex_args" \
    "$PLUGIN_ROOT/bin/plx-engine" --engine codex --mode ro --repo "$REPO" \
    --prompt-file "$fake_prompt" --model "$retired_model" \
    --out "$fake_out" --log "$fake_log" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 2 ]; then
    _pass "retired model $retired_model is rejected"
  else
    _fail "retired model $retired_model expected exit 2, got $rc"
  fi
done

PATH="$fake_bin:$PATH" PLX_CODEX_ARGS_FILE="$fake_codex_args" \
  "$PLUGIN_ROOT/bin/plx-engine" --engine codex --mode rw --repo "$REPO" \
  --prompt-file "$fake_prompt" --rubric worker --build-writer-full-access \
  --out "$fake_out" --log "$fake_log" >/dev/null
rc=$?
if [ "$rc" -eq 0 ]; then
  _pass "Codex Build writer full-access invocation exits 0"
else
  _fail "Codex Build writer full-access invocation exits $rc"
fi
assert_contains "danger-full-access" "$fake_codex_args" "Codex Build writer receives full-access sandbox"
if grep -qF -- '--dangerously-bypass-approvals-and-sandbox' "$fake_codex_args"; then
  _fail "Codex Build writer bypasses approvals and sandbox"
else
  _pass "Codex Build writer does not use the approvals-and-sandbox bypass"
fi

PATH="$fake_bin:$PATH" PLX_CODEX_ARGS_FILE="$fake_codex_args" \
  "$PLUGIN_ROOT/bin/plx-engine" --engine codex --mode rw --repo "$REPO" \
  --prompt-file "$fake_prompt" --rubric build-worker --build-writer-full-access \
  --out "$fake_out" --log "$fake_log" >/dev/null
rc=$?
if [ "$rc" -eq 0 ]; then
  _pass "Codex build-worker full-access invocation exits 0"
else
  _fail "Codex build-worker full-access invocation exits $rc"
fi

"$PLUGIN_ROOT/bin/plx-engine" --engine codex --mode ro --repo "$REPO" \
  --prompt-file "$fake_prompt" --rubric worker --build-writer-full-access \
  --out "$fake_out" --log "$fake_log" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 2 ]; then
  _pass "Build writer full access rejects read-only mode"
else
  _fail "Build writer full access in read-only mode expected exit 2, got $rc"
fi
"$PLUGIN_ROOT/bin/plx-engine" --engine codex --mode rw --repo "$REPO" \
  --prompt-file "$fake_prompt" --rubric reviewer-correctness --build-writer-full-access \
  --out "$fake_out" --log "$fake_log" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 2 ]; then
  _pass "Build writer full access rejects reviewer rubrics"
else
  _fail "Build writer full access with reviewer rubric expected exit 2, got $rc"
fi
"$PLUGIN_ROOT/bin/plx-engine" --engine grok --mode rw --repo "$REPO" \
  --prompt-file "$fake_prompt" --rubric worker --build-writer-full-access \
  --out "$fake_out" --log "$fake_log" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 2 ]; then
  _pass "Build writer full access rejects Grok"
else
  _fail "Build writer full access with Grok expected exit 2, got $rc"
fi

PATH="$fake_bin:$PATH" PLX_CODEX_ARGS_FILE="$fake_codex_args" \
  "$PLUGIN_ROOT/bin/plx-engine" --engine codex --mode ro --repo "$REPO" \
  --prompt-file "$fake_prompt" --model gpt-6-sol --effort xhigh \
  --out "$fake_out" --log "$fake_log" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 0 ] &&
   grep -qx "gpt-6-sol" "$fake_codex_args" &&
   grep -qx "model_reasoning_effort=xhigh" "$fake_codex_args"; then
  _pass "GPT-6 Sol model and effort override passes through"
else
  _fail "GPT-6 Sol override did not pass through (exit $rc)"
fi

PATH="$fake_bin:$PATH" PLX_CODEX_ARGS_FILE="$fake_codex_args" \
  "$PLUGIN_ROOT/bin/plx-engine" --engine codex --mode ro --repo "$REPO" \
  --prompt-file "$fake_prompt" --model gpt-6-luna --effort low \
  --out "$fake_out" --log "$fake_log" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 0 ] &&
   grep -qx "gpt-6-luna" "$fake_codex_args" &&
   grep -qx "model_reasoning_effort=low" "$fake_codex_args"; then
  _pass "GPT-6 Luna model and effort override passes through"
else
  _fail "GPT-6 Luna override did not pass through (exit $rc)"
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
  assert_contains "gpt-6-sol" "$cxa_args" "persistent Codex model defaults to GPT-6 Sol"
  assert_contains "medium" "$cxa_args" "persistent Codex effort defaults to medium"
  assert_contains "$PLUGIN_ROOT/bin/../tools/codex-app-client" "$cxa_args" "uses the packaged app client"
  assert_contains "$WORK/cache/parallax/codex-app-client" "$cxa_env" "uv environment stays outside the plugin"
  assert_contains "reply OK" "$cxa_prompt" "prompt is sent over stdin"

  PATH="$fake_bin:$PATH" PLX_CXA_ARGS_FILE="$cxa_args" \
    PLX_CXA_PROMPT_FILE="$cxa_prompt" PLX_CXA_ENV_FILE="$cxa_env" \
    XDG_CACHE_HOME="$WORK/cache" \
    "$PLUGIN_ROOT/bin/plx-codex-thread" resume --thread thread-123 \
    --repo "$REPO" --mode rw --prompt-file "$fake_prompt" \
    --model gpt-6-luna --effort max > "$WORK/cxa-resume.json"
  rc=$?
  if [ "$rc" -eq 0 ]; then _pass "persistent resume exits 0"; else _fail "persistent resume exits $rc"; fi
  assert_contains "thread-123" "$cxa_args" "resume passes the thread ID"
  assert_contains "edit" "$cxa_args" "rw maps to edit"
  assert_contains "gpt-6-luna" "$cxa_args" "persistent model override passes through"
  assert_contains "max" "$cxa_args" "persistent effort override passes through"
  "$PLUGIN_ROOT/bin/plx-codex-thread" start --repo "$REPO" --mode ro \
    --prompt-file "$fake_prompt" --model gpt-5.6-sol >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 2 ]; then
    _pass "persistent Codex rejects retired model"
  else
    _fail "persistent Codex retired model expected exit 2, got $rc"
  fi
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
mkdir -p "$REPO/ignored-guidance" "$REPO/untracked-guidance" "$REPO/.claude/rules"
printf '%s\n' '/ignored-guidance/' >> "$REPO/.gitignore"
printf '%s\n' '# ignored nested guidance' > "$REPO/ignored-guidance/AGENTS.md"
printf '%s\n' '# untracked nested guidance' > "$REPO/untracked-guidance/AGENTS.md"
ln -s AGENTS.md "$REPO/untracked-guidance/CLAUDE.md"
printf '%s\n' '# path-scoped rule' > "$REPO/.claude/rules/review.md"
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
  --prompt-file "$fake_prompt" --out "$fake_out" --log "$fake_log" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 0 ] && grep -qx "claude-opus-5-5" "$fake_claude_args"; then
  _pass "Claude defaults to pinned Opus 5.5"
else
  _fail "Claude pinned default failed (exit $rc)"
fi

PATH="$fake_bin:$PATH" PLX_CLAUDE_ARGS_FILE="$fake_claude_args" \
  PLX_CLAUDE_PROMPT_FILE="$fake_claude_prompt" \
  "$PLUGIN_ROOT/bin/plx-engine" --engine claude --mode ro --repo "$REPO" \
  --prompt-file "$fake_prompt" --model claude-opus-5-5 --effort max \
  --out "$fake_out" --log "$fake_log" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 0 ] &&
   grep -qx "claude-opus-5-5" "$fake_claude_args" &&
   grep -qx "max" "$fake_claude_args"; then
  _pass "Claude Opus 5.5 model and effort override passes through"
else
  _fail "Claude Opus 5.5 override did not pass through (exit $rc)"
fi
for flag in --safe-mode --no-session-persistence --strict-mcp-config --mcp-config; do
  assert_contains "$flag" "$fake_claude_args" "Claude ro receives $flag"
done
assert_contains "dontAsk" "$fake_claude_args" "Claude ro cannot prompt for broader permissions"
assert_contains "Read,Grep,Glob" "$fake_claude_args" "Claude ro exposes only read tools"
assert_contains '"failIfUnavailable":true' "$fake_claude_args" "Claude sandbox fails closed"
assert_contains '"strictAllowlist":true' "$fake_claude_args" "Claude network allowlist is strict"
assert_contains '{"mcpServers":{}}' "$fake_claude_args" "Claude receives an empty MCP configuration"
assert_contains "ignored-guidance/AGENTS.md" "$fake_claude_prompt" "Claude sees ignored nested guidance"
assert_contains "untracked-guidance/CLAUDE.md" "$fake_claude_prompt" "Claude sees untracked symlink guidance"
assert_contains ".claude/rules/review.md" "$fake_claude_prompt" "Claude sees path-scoped rules"
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

PATH="$fake_bin:$PATH" PLX_CLAUDE_ARGS_FILE="$fake_claude_args" \
  PLX_CLAUDE_PROMPT_FILE="$fake_claude_prompt" \
  "$PLUGIN_ROOT/bin/plx-engine" --engine claude --mode rw --repo "$REPO" \
  --prompt-file "$fake_prompt" --rubric worker --build-writer-full-access \
  --out "$fake_out" --log "$fake_log" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then
  _pass "Claude Build writer full-access invocation exits 0"
else
  _fail "Claude Build writer full-access invocation exits $rc"
fi
assert_contains "--dangerously-skip-permissions" "$fake_claude_args" "Claude Build writer bypasses host permission prompts"
assert_contains '"enabled":false' "$fake_claude_args" "Claude Build writer disables the Claude sandbox"
assert_contains "only so this standalone Build worker can write repository Git metadata and launch its packaged review lanes" \
  "$fake_claude_prompt" "Claude full-access prompt preserves the task authority boundary"
rm -f -- \
  "$REPO/ignored-guidance/AGENTS.md" \
  "$REPO/untracked-guidance/AGENTS.md" \
  "$REPO/untracked-guidance/CLAUDE.md" \
  "$REPO/.claude/rules/review.md"
rmdir "$REPO/ignored-guidance" "$REPO/untracked-guidance" \
  "$REPO/.claude/rules" "$REPO/.claude"

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
  'printf '\''{"text":"OK","stopReason":"end_turn","sessionId":""}\n'\''' \
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
assert con.execute("pragma user_version").fetchone()[0] == 2
assert con.execute("pragma integrity_check").fetchone()[0] == "ok"
PY
then
  _pass "schema v2 stores complete task, prompt, trace, output, and digest"
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
  'printf '\''{"text":"OK","stopReason":"end_turn","sessionId":""}\n'\''' \
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

legacy_db="$WORK/legacy-schema.db"
invalid_legacy_db="$WORK/invalid-legacy-schema.db"
cp "$trace_db" "$legacy_db"
python3 - "$legacy_db" <<'PY'
import sqlite3, sys
con = sqlite3.connect(sys.argv[1])
schema = con.execute("select sql from sqlite_schema where name='lanes'").fetchone()[0]
legacy_schema = schema.replace(", 'full-access'", "")
assert "full-access" not in legacy_schema
con.execute("drop index lanes_run_id_idx")
con.execute("alter table lanes rename to lanes_v2_seed")
con.execute(legacy_schema)
con.execute("insert into lanes select * from lanes_v2_seed")
con.execute("drop table lanes_v2_seed")
con.execute("create index lanes_run_id_idx on lanes(run_id)")
con.execute("pragma user_version=1")
con.commit()
PY
cp "$legacy_db" "$invalid_legacy_db"
python3 - "$invalid_legacy_db" <<'PY'
import sqlite3, sys
con = sqlite3.connect(sys.argv[1])
con.execute("pragma foreign_keys=off")
con.execute(
    "insert into lanes(id,run_id,role,engine,model,effort,mode,started_at) "
    "values('orphan','missing','r','grok','m','e','ro','now')"
)
con.commit()
PY

PLX_TRACE_DB="$legacy_db" "$PLUGIN_ROOT/bin/plx-eval" doctor >/dev/null 2>&1
legacy_rc=$?
if [ "$legacy_rc" -eq 0 ] && python3 - "$legacy_db" <<'PY'
import sqlite3, sys
con = sqlite3.connect(sys.argv[1])
assert con.execute("pragma user_version").fetchone()[0] == 2
assert "'full-access'" in con.execute(
    "select sql from sqlite_schema where name='lanes'"
).fetchone()[0]
before = con.execute("select count(*) from lanes").fetchone()[0]
run_id = con.execute("select id from runs limit 1").fetchone()[0]
con.execute(
    "insert into lanes(id,run_id,role,engine,model,effort,mode,started_at) "
    "values('devin-v2',?,'worker','devin','swe-2-medium','','full-access','now')",
    (run_id,),
)
con.commit()
assert con.execute("select count(*) from lanes").fetchone()[0] == before + 1
assert con.execute("pragma foreign_key_check").fetchall() == []
PY
then
  _pass "schema v1 migrates in place and accepts Devin full-access lanes"
else
  _fail "schema v1 migration failed or lost lane data"
fi

PLX_TRACE_DB="$invalid_legacy_db" "$PLUGIN_ROOT/bin/plx-eval" doctor >/dev/null 2>&1
invalid_legacy_rc=$?
if [ "$invalid_legacy_rc" -eq 1 ] && python3 - "$invalid_legacy_db" <<'PY'
import sqlite3, sys
con = sqlite3.connect(sys.argv[1])
assert con.execute("pragma user_version").fetchone()[0] == 1
assert con.execute("select count(*) from sqlite_schema where type='table' and name='lanes'").fetchone()[0] == 1
assert con.execute("select count(*) from sqlite_schema where type='table' and name='lanes_v2'").fetchone()[0] == 0
assert "full-access" not in con.execute(
    "select sql from sqlite_schema where name='lanes'"
).fetchone()[0]
PY
then
  _pass "schema migration validation rolls back invalid legacy data"
else
  _fail "invalid schema v1 migration did not fail and roll back"
fi

future_db="$WORK/future-schema.db"
python3 - "$future_db" <<'PY'
import sqlite3, sys
con = sqlite3.connect(sys.argv[1])
con.execute("pragma user_version=3")
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
if cmp -s "$out" "$PLUGIN_ROOT/skills/dev/SKILL.md"; then
  _pass "emits the complete source skill"
else
  _fail "skill output differs from its source"
fi
out="$WORK/simplify-skill.txt"
"$PLUGIN_ROOT/bin/plx-skill" simplify > "$out" 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then _pass "simplify exits 0"; else _fail "simplify exit $rc"; fi
assert_contains "## Simplification principles" "$out" "emits the Simplify pipeline"
out="$WORK/kiss-skill.txt"
"$PLUGIN_ROOT/bin/plx-skill" kiss > "$out" 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then _pass "kiss exits 0"; else _fail "kiss exit $rc"; fi
assert_contains "# KISS principles" "$out" "emits the KISS principles"
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
  'printf '\''{"text":"OK","stopReason":"end_turn","sessionId":""}\n'\''' \
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
