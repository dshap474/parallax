#!/usr/bin/env bash
# Validate both Parallax packages without invoking any model engine.
# Usage: tests/check-plugin.sh
set -uo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

# --------------------------------------------------------------------------- #
# Manifests and versions
# --------------------------------------------------------------------------- #

_head "Marketplace and plugin manifests"
for file in \
  .claude-plugin/marketplace.json \
  .agents/plugins/marketplace.json \
  plugins/claude/plx/.claude-plugin/plugin.json \
  plugins/codex/plx/.codex-plugin/plugin.json; do
  if python3 -m json.tool "$PLX_ROOT/$file" >/dev/null 2>&1; then
    _pass "$file"
  else
    _fail "missing or invalid JSON: $file"
  fi
done

version_of() {
  sed -n 's/^[[:space:]]*"version": "\([^"]*\)".*/\1/p' "$1" | head -1
}

claude_version="$(version_of "$PLX_CLAUDE/.claude-plugin/plugin.json")"
codex_version="$(version_of "$PLX_CODEX/.codex-plugin/plugin.json")"
market_version="$(version_of "$PLX_ROOT/.claude-plugin/marketplace.json")"
if [ "$claude_version" = "0.5.37" ] && [ "$claude_version" = "$codex_version" ] &&
   [ "$claude_version" = "$market_version" ] &&
   grep -qx "v$claude_version" "$PLX_ROOT/README.md" &&
   grep -qx "Status: v$claude_version" "$PLX_ROOT/docs/SPEC.md"; then
  _pass "release surfaces agree at $claude_version"
else
  _fail "release version drift"
fi

# --------------------------------------------------------------------------- #
# Skill surfaces and polarity
# --------------------------------------------------------------------------- #

_head "Sixteen host-native skills per package"
claude_count="$(find "$PLX_CLAUDE/skills" -mindepth 2 -maxdepth 2 -name SKILL.md | wc -l | tr -d ' ')"
codex_count="$(find "$PLX_CODEX/skills" -mindepth 2 -maxdepth 2 -name SKILL.md | wc -l | tr -d ' ')"
[ "$claude_count" = 16 ] && _pass "Claude skills: 16" || _fail "Claude skills: $claude_count"
[ "$codex_count" = 16 ] && _pass "Codex skills: 16" || _fail "Codex skills: $codex_count"

for skill in "$PLX_CLAUDE"/skills/*/SKILL.md; do
  name="$(basename "$(dirname "$skill")")"
  declared_name="$(sed -n 's/^name:[[:space:]]*//p' "$skill" | head -1)"
  if [ "$declared_name" = "$name" ]; then
    _pass "Claude $name invocation: /plx:$name"
  else
    _fail "Claude $name repeats or changes the plugin namespace: $declared_name"
  fi
  if grep -qx 'disable-model-invocation: true' "$skill" &&
     grep -qx 'user-invocable: true' "$skill"; then
    _pass "Claude $name explicit-only"
  else
    _fail "Claude $name missing explicit-only metadata"
  fi
done
for skill in "$PLX_CODEX"/skills/*/SKILL.md; do
  name="$(basename "$(dirname "$skill")")"
  declared_name="$(sed -n 's/^name:[[:space:]]*//p' "$skill" | head -1)"
  if [ "$declared_name" = "$name" ]; then
    _pass "Codex $name invocation: \$plx:$name"
  else
    _fail "Codex $name repeats or changes the plugin namespace: $declared_name"
  fi
  metadata="$(dirname "$skill")/agents/openai.yaml"
  if [ -f "$metadata" ] && grep -q 'allow_implicit_invocation: false' "$metadata"; then
    _pass "Codex $name explicit-only"
  else
    _fail "Codex $name missing explicit-only metadata"
  fi
  case "$name" in
    build) display_name="PLX::Build" ;;
    claude) display_name="PLX::Claude" ;;
    gemini) display_name="PLX::Gemini" ;;
    devin) display_name="PLX::Devin" ;;
    dev) display_name="PLX::Dev" ;;
    grok) display_name="PLX::Grok" ;;
    init) display_name="PLX::Init" ;;
    plan) display_name="PLX::Plan" ;;
    review) display_name="PLX::Review" ;;
    kiss) display_name="PLX::KISS" ;;
    orchestrate) display_name="PLX::Orchestrate" ;;
    simplify) display_name="PLX::Simplify" ;;
    unknown-unknowns) display_name="PLX::UnknownUnknowns" ;;
    fanout-and-synthesize) display_name="PLX::FanoutAndSynthesize" ;;
    adversarial-verification) display_name="PLX::AdversarialVerification" ;;
    generate-and-filter) display_name="PLX::GenerateAndFilter" ;;
    *) display_name="" ;;
  esac
  if [ -n "$display_name" ] && grep -qx "  display_name: \"$display_name\"" "$metadata"; then
    _pass "Codex $name display: $display_name"
  else
    _fail "Codex $name display name is not PLX PascalCase"
  fi
  if grep -Fq "Use \$plx:$name " "$metadata"; then
    _pass "Codex $name default prompt uses the namespaced invocation"
  else
    _fail "Codex $name default prompt does not use \$plx:$name"
  fi
done

if [ -f "$PLX_CLAUDE/skills/codex/SKILL.md" ] &&
   [ -f "$PLX_CODEX/skills/claude/SKILL.md" ] &&
   [ ! -e "$PLX_CODEX/skills/codex" ]; then
  _pass "opposite-host passthroughs are platform-correct"
else
  _fail "opposite-host passthrough contract is wrong"
fi

passthrough_ok=1
for spec in \
  "$PLX_CLAUDE/skills/codex:codex:--codex-passthrough-full-access:gpt-6.1-sol" \
  "$PLX_CODEX/skills/claude:claude:--claude-passthrough-full-access:claude-opus-5-5" \
  "$PLX_CLAUDE/skills/grok:grok::grok-4.6" "$PLX_CODEX/skills/grok:grok::grok-4.6" \
  "$PLX_CLAUDE/skills/devin:devin:--mode full-access:swe-2-high" \
  "$PLX_CODEX/skills/devin:devin:--mode full-access:swe-2-high"; do
  IFS=: read -r dir engine flag model <<< "$spec"
  skill="$dir/SKILL.md"
  grep -Fq -- "plx-engine --engine $engine" "$skill" || passthrough_ok=0
  grep -Fq -- "--model <model>" "$skill" || passthrough_ok=0
  grep -Fq -- "$model" "$skill" || passthrough_ok=0
  [ -z "$flag" ] || grep -Fq -- "$flag" "$skill" || passthrough_ok=0
done
if [ "$passthrough_ok" -eq 1 ]; then
  _pass "single-engine passthroughs launch their engine with the default model and access flag"
else
  _fail "single-engine passthrough launch contract drift"
fi

simplify_contract_ok=1
for package_host in "$PLX_CLAUDE:Codex:gpt-6.1-sol:/plx:codex" "$PLX_CODEX:Claude:claude-opus-5-5:\$plx:claude"; do
  package="${package_host%%:*}"
  settings="${package_host#*:}"
  engine="${settings%%:*}"
  settings="${settings#*:}"
  model="${settings%%:*}"
  passthrough="${settings#*:}"
  skill="$package/skills/simplify/SKILL.md"
  grep -Fq "\`$model\`" "$skill" || simplify_contract_ok=0
  grep -Fq -- '--model <model>' "$skill" || simplify_contract_ok=0
  for rubric in reuse simplification efficiency altitude; do
    grep -Fq "simplify-$rubric" "$skill" || simplify_contract_ok=0
  done
done
if [ "$simplify_contract_ok" -eq 1 ]; then
  _pass "Simplify keeps four opposite-engine Medium dimensions and host synthesis"
else
  _fail "Simplify fixed-shape contract drift"
fi

if grep -Eq 'plx-engine|--mode (ro|rw)' \
     "$PLX_CLAUDE"/skills/{kiss,orchestrate}/SKILL.md \
     "$PLX_CODEX"/skills/{kiss,orchestrate}/SKILL.md; then
  _fail "KISS and Orchestrate must remain context-only"
else
  _pass "KISS and Orchestrate are context-only"
fi
if grep -Fq '`gpt-6.1-sol`' \
     "$PLX_CODEX/skills/orchestrate/SKILL.md"; then
  _pass "Codex Orchestrate workers default to GPT-6.1 Sol Medium"
else
  _fail "Codex Orchestrate worker default drift"
fi

# Check launch contracts and cross-host copies; prose wording is not a runtime API.
review_contract_ok=1
for package_host in "$PLX_CLAUDE:Codex:gpt-6.1-sol:/plx:codex" "$PLX_CODEX:Claude:claude-opus-5-5:\$plx:claude"; do
  package="${package_host%%:*}"
  settings="${package_host#*:}"
  engine="${settings%%:*}"
  settings="${settings#*:}"
  model="${settings%%:*}"
  passthrough="${settings#*:}"
  skill="$package/skills/review/SKILL.md"
  for role in correctness cleanup structural security; do
    grep -Fq "reviewer-$role" "$skill" || review_contract_ok=0
  done
  for token in '--mode ro' '--model <model> --effort <effort>'; do
    grep -Fq -- "$token" "$skill" || review_contract_ok=0
  done
  grep -Fq "\`$model\`" "$skill" || review_contract_ok=0
  grep -Fq "\`$passthrough\`" "$skill" || review_contract_ok=0
done
if [ "$review_contract_ok" -eq 1 ]; then
  _pass "standalone review supplies core and security roles with explicit read-only launch settings"
else
  _fail "standalone review launch contract drift"
fi


if python3 - "$PLX_ROOT" <<'PY_CONTRACT'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
errors = []
for host, model, effort in (("claude", "claude-opus-5-5", "medium"), ("codex", "gpt-6.1-sol", "medium")):
    package = root / "plugins" / host / "plx"
    build = (package / "skills/build/SKILL.md").read_text()
    commands = [" ".join(block.replace("\\\n", " ").split())
                for block in re.findall(r"```[^\n]*\n(.*?)```", build, re.S)]
    launch = [block for block in commands if "--rubric build-worker" in block]
    required = (f"--engine {host} --mode rw", "--build-writer-full-access",
                f"--model {model} --effort {effort}", "--prompt-file <tmp>/writer-brief.md")
    if len(launch) != 1 or not all(flag in launch[0] for flag in required):
        errors.append(f"{host}: standalone Build must launch one configured worker")
    if "--rubric reviewer-" in build or "--require-grok" in build:
        errors.append(f"{host}: Build must not run its own review")
    for field in ("## Spec", "## Build run context", "Baseline commit:",
                  "Pre-existing changes:", "Verification suite:"):
        if field not in build:
            errors.append(f"{host}: Build handoff missing {field}")
    plan = (package / "skills/plan/SKILL.md").read_text()
    critic = "claude" if host == "codex" else "codex"
    model = "claude-fable-5-1" if host == "codex" else "gpt-6-astra"
    commands = [" ".join(block.replace("\\\n", " ").split())
                for block in re.findall(r"```[^\n]*\n(.*?)```", plan, re.S)]
    launches = [block for block in commands if "--rubric plan-critic" in block]
    if len(launches) != 1 or not all(flag in launches[0] for flag in
        (f"--engine {critic} --mode ro", f"--model {model}", "--rubric plan-critic")):
        errors.append(f"{host}: Plan must run one opposite-host reviewer")
    dev = (package / "skills/dev/SKILL.md").read_text()
    calls = re.findall(r"plx-skill (plan|build|review)\b", dev)
    if calls != ["plan", "build", "review"] or "plx-engine" in dev:
        errors.append(f"{host}: Dev must compose Plan, Build, Review in order")

# These workflows differ only in native invocation, model polarity, and host transport.
# Compare normalized bodies to catch a change shipped to only one host, independently
# of headings, line wrapping, or the particular wording chosen for shared instructions.
for name in ("build", "dev", "plan", "review", "unknown-unknowns"):
    bodies = []
    for host in ("claude", "codex"):
        body = (root / f"plugins/{host}/plx/skills/{name}/SKILL.md").read_text().split("---", 2)[2]
        body = re.sub(r"Resolve `<plugin-root>` from this loaded `SKILL.md` path.*?Use (?:the packaged helpers in|its packaged helpers in) `<plugin-root>/bin/`\.", "Use the packaged helpers on PATH.", body, flags=re.S)
        body = re.sub(r"If the host sandbox blocks Claude or Grok network/keychain access,.*?(?:active|transport)\.", "HOST_BOUNDARY", body, flags=re.S)
        body = re.sub(r"For Grok calls,.*?active\.", "HOST_BOUNDARY", body, flags=re.S)
        body = body.replace("<plugin-root>/bin/", "").replace("$plx:", "/plx:")
        if name == "build":
            body = body.replace("gpt-6.1-sol", "claude-opus-5-5")
            body = body.replace("Codex", "Claude").replace("codex", "claude")
        else:
            body = body.replace(f"--host {host}", "--host HOST")
            opposite = "claude" if host == "codex" else "codex"
            body = body.replace(f"`{opposite}`", "`OPPOSITE`")
            body = body.replace("request_user_input", "AskUserQuestion")
            if name == "plan":
                body = body.replace("claude-fable-5-1", "PLAN_REVIEWER").replace("gpt-6-astra", "PLAN_REVIEWER")
                body = body.replace(f"--engine {opposite}", "--engine OPPOSITE").replace(f"--require-{opposite}", "--require-OPPOSITE")
            if name == "dev":
                body = body.replace("`high`", "`REVIEW_EFFORT`") if host == "codex" else body.replace("`xhigh`", "`REVIEW_EFFORT`")
            if name == "review":
                body = body.replace("Codex `gpt-6.1-sol`", "OPPOSITE `MODEL`") if host == "claude" else body.replace("Claude `claude-opus-5-5`", "OPPOSITE `MODEL`", 1)
                body = body.replace("`/plx:codex`", "`OPPOSITE_PASSTHROUGH`").replace("`/plx:claude`", "`OPPOSITE_PASSTHROUGH`")
        bodies.append(" ".join(body.split()))
    if bodies[0] != bodies[1]:
        errors.append(f"{name}: host-normalized workflow bodies differ")

template = "skills/plan/references/spec-template.md"
if (root / "plugins/claude/plx" / template).read_bytes() != (root / "plugins/codex/plx" / template).read_bytes():
    errors.append("spec templates differ between hosts")
for error in errors:
    print(error, file=sys.stderr)
sys.exit(bool(errors))
PY_CONTRACT
then
  _pass "Build launch/handoff contracts and host-normalized workflow parity"
else
  _fail "Build launch/handoff or host workflow parity drift"
fi

plan_brief_ok=1
for host in claude codex; do
  for field in '## Draft plan' '### Original request' '### Confirmed decisions' '### Candidate plan'; do
    grep -Fq "$field" "$PLX_ROOT/plugins/$host/plx/skills/plan/SKILL.md" || plan_brief_ok=0
  done
done
if [ "$plan_brief_ok" -eq 1 ]; then
  _pass "Plan critic brief keeps its structured fields"
else
  _fail "Plan critic brief field drift"
fi

# --------------------------------------------------------------------------- #
# Runtime packaging
# --------------------------------------------------------------------------- #

_head "Shared runtime copies"
if "$PLX_ROOT/scripts/sync-shared.sh" --check >/dev/null; then
  _pass "shared bin/prompts/license copies are current"
else
  _fail "shared runtime drift"
fi

SYNC_TMP="$(mktemp -d "${TMPDIR:-/tmp}/plx-sync-check.XXXXXX")"
trap 'rm -rf "$SYNC_TMP"' EXIT
SYNC_REPO="$SYNC_TMP/repo"
mkdir -p "$SYNC_REPO/scripts" "$SYNC_REPO/plugins/claude/plx" "$SYNC_REPO/plugins/codex/plx"
cp -R "$PLX_ROOT/shared" "$SYNC_REPO/shared"
cp "$PLX_ROOT/LICENSE" "$SYNC_REPO/LICENSE"
cp "$PLX_ROOT/scripts/sync-shared.sh" "$SYNC_REPO/scripts/sync-shared.sh"
"$SYNC_REPO/scripts/sync-shared.sh" >/dev/null
printf 'orphan\n' > "$SYNC_REPO/plugins/codex/plx/prompts/orphan.md"
orphan_output="$("$SYNC_REPO/scripts/sync-shared.sh" --check 2>&1)"
orphan_rc=$?
if [ "$orphan_rc" -eq 1 ] && printf '%s\n' "$orphan_output" | grep -q 'orphan: plugins/codex/plx/prompts/orphan.md'; then
  _pass "shared check rejects destination-only files"
else
  _fail "shared check missed a destination-only file"
fi
"$SYNC_REPO/scripts/sync-shared.sh" >/dev/null
if [ ! -e "$SYNC_REPO/plugins/codex/plx/prompts/orphan.md" ]; then
  _pass "shared sync prunes destination-only files"
else
  _fail "shared sync left a destination-only file"
fi

atomic_source="$SYNC_REPO/shared/bin/plx-atomic-probe"
atomic_destination="$SYNC_REPO/plugins/claude/plx/bin/plx-atomic-probe"
printf '%s\n' old > "$atomic_source"
chmod +x "$atomic_source"
"$SYNC_REPO/scripts/sync-shared.sh" >/dev/null
exec 9< "$atomic_destination"
printf '%s\n' new > "$atomic_source"
"$SYNC_REPO/scripts/sync-shared.sh" >/dev/null
old_copy="$(cat <&9)"
exec 9<&-
new_copy="$(cat "$atomic_destination")"
if [ "$old_copy" = old ] && [ "$new_copy" = new ] && [ -x "$atomic_destination" ]; then
  _pass "shared sync atomically replaces files without changing active readers"
else
  _fail "shared sync changed an active reader or lost the executable mode"
fi
rm -f -- "$atomic_source"
"$SYNC_REPO/scripts/sync-shared.sh" >/dev/null

for package in "$PLX_CLAUDE" "$PLX_CODEX"; do
  label="$(basename "$(dirname "$package")")"
  for tool in plx-engine plx-skill plx-clean-temp; do
    [ -x "$package/bin/$tool" ] && _pass "$label bin/$tool" || _fail "$label bin/$tool"
  done
  for rubric in plan-critic build-worker reviewer-correctness reviewer-cleanup reviewer-structural reviewer-security simplify-reuse simplify-simplification simplify-efficiency simplify-altitude; do
    [ -s "$package/prompts/$rubric.md" ] || _fail "$label missing rubric $rubric"
  done
done

if find "$PLX_CLAUDE/skills" "$PLX_CODEX/skills" -name SKILL.md \
     ! -path '*/skills/orchestrate/SKILL.md' -print0 |
     xargs -0 grep -Eqi 'use subagents|spawn (a |an )?subagent'; then
  _fail "a skill besides Orchestrate instructs subagent orchestration"
else
  _pass "subagent orchestration is isolated to Orchestrate"
fi
if find "$PLX_ROOT/plugins" -type d -name .parallax | grep -q .; then
  _fail "repo-local runtime state exists"
else
  _pass "no .parallax runtime state"
fi
if grep -RE '^[[:space:]]*[^#].*(dangerously-bypass-approvals-and-sandbox|--yolo)' \
  "$PLX_ROOT/shared/bin" >/dev/null; then
  _fail "forbidden approvals-and-sandbox bypass in shared runtime"
elif [ "$(grep -Fc 'sandbox="danger-full-access"' "$PLX_ROOT/shared/bin/plx-engine")" -ne 1 ] ||
     [ "$(grep -Fc 'flags+=(--dangerously-skip-permissions' "$PLX_ROOT/shared/bin/plx-engine")" -ne 2 ] ||
     find "$PLX_ROOT/shared/bin" -type f ! -name plx-engine -exec \
       grep -El 'danger-full-access|dangerously-skip-permissions' {} + | grep -q .; then
  _fail "explicit full-access runtime boundary drift"
elif ! grep -Fq -- '--permission-mode dangerous' "$PLX_ROOT/shared/bin/plx-engine" ||
     ! grep -Fq 'Devin requires --mode full-access' "$PLX_ROOT/shared/bin/plx-engine" ||
     ! grep -Fq 'elif [[ "$MODE" == "full-access" ]]' "$PLX_ROOT/shared/bin/plx-engine"; then
  _fail "Devin full-access transport boundary drift"
else
  _pass "full access is explicit for Build, opposite-host passthroughs, and Devin"
fi
if grep -RE '^[[:space:]]*[^#].*rm[[:space:]]+-rf' \
     "$PLX_ROOT/shared/bin" "$PLX_ROOT/plugins/claude/plx/bin" \
     "$PLX_ROOT/plugins/claude/plx/skills" "$PLX_ROOT/plugins/codex/plx/bin" \
     "$PLX_ROOT/plugins/codex/plx/skills" >/dev/null; then
  _fail "shipped runtime or skills contain policy-blocked recursive cleanup"
else
  _pass "shipped cleanup avoids recursive rm"
fi
if grep -RE 'mktemp[[:space:]]+-d([^[:alnum:]]|$)' \
     "$PLX_ROOT/plugins" | grep -v 'plx-[[:alnum:]-]*\.XXXXXX' >/dev/null; then
  _fail "a skill creates an unconfined temporary directory"
else
  _pass "skill temporary directories use explicit plx prefixes"
fi

# --------------------------------------------------------------------------- #
# Maintainer helper contracts
# --------------------------------------------------------------------------- #

_head "Maintainer helper contracts"
"$PLX_ROOT/tests/smoke-scripts.sh" codex >/dev/null 2>&1
smoke_rc=$?
if [ "$smoke_rc" -eq 2 ]; then
  _pass "smoke harness rejects positional package selectors"
else
  _fail "smoke harness silently accepted a positional package selector"
fi

explain_output="$("$PLX_ROOT/tests/explain-skill.sh" codex dev)"
if printf '%s\n' "$explain_output" | grep -q 'plx-skill plan' &&
   printf '%s\n' "$explain_output" | grep -q 'plx-skill build' &&
   printf '%s\n' "$explain_output" | grep -q 'plx-skill review'; then
  _pass "skill explanation shows Dev composition"
else
  _fail "skill explanation omitted Dev composition"
fi

summary
