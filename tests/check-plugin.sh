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
if [ "$claude_version" = "0.5.8" ] && [ "$claude_version" = "$codex_version" ] &&
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

_head "Ten host-native skills per package"
claude_count="$(find "$PLX_CLAUDE/skills" -mindepth 2 -maxdepth 2 -name SKILL.md | wc -l | tr -d ' ')"
codex_count="$(find "$PLX_CODEX/skills" -mindepth 2 -maxdepth 2 -name SKILL.md | wc -l | tr -d ' ')"
[ "$claude_count" = 10 ] && _pass "Claude skills: 10" || _fail "Claude skills: $claude_count"
[ "$codex_count" = 10 ] && _pass "Codex skills: 10" || _fail "Codex skills: $codex_count"

for skill in "$PLX_CLAUDE"/skills/*/SKILL.md; do
  name="$(basename "$(dirname "$skill")")"
  declared_name="$(sed -n 's/^name:[[:space:]]*//p' "$skill" | head -1)"
  if [ "$declared_name" = "$name" ]; then
    _pass "Claude $name invocation: /plx:$name"
  else
    _fail "Claude $name repeats or changes the plugin namespace: $declared_name"
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
    agents-memory) display_name="PLX::AgentsMemory" ;;
    build) display_name="PLX::Build" ;;
    claude) display_name="PLX::Claude" ;;
    dev) display_name="PLX::Dev" ;;
    goal-spec) display_name="PLX::GoalSpec" ;;
    grok) display_name="PLX::Grok" ;;
    init) display_name="PLX::Init" ;;
    plan) display_name="PLX::Plan" ;;
    review) display_name="PLX::Review" ;;
    unknown-unknowns) display_name="PLX::UnknownUnknowns" ;;
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

agents_memory_template="$PLX_CODEX/skills/agents-memory/references/AGENTS.template.md"
claude_agents_memory_template="$PLX_CLAUDE/skills/agents-memory/references/AGENTS.template.md"
if grep -Fq 'Use `.project/` only when it will prevent meaningful rediscovery' "$agents_memory_template" &&
   grep -Fq '`builds/` — optional working records' "$agents_memory_template" &&
   grep -Fq '`adr/` — decisions that durably change system boundaries' "$agents_memory_template" &&
   grep -Fq '`architecture/` — current-state explanations of larger systems' "$agents_memory_template" &&
   grep -Fq '`VISION.md` — user-owned and read-only' "$agents_memory_template" &&
   ! grep -Fq 'one thread per session' "$agents_memory_template" &&
   ! grep -Fq 'keep a `README.md` index' "$agents_memory_template" &&
   ! grep -Fq 'security/threat-model.md' "$agents_memory_template"; then
  _pass "Codex agents-memory uses the selective project-docs contract"
else
  _fail "Codex agents-memory project-docs contract drift"
fi
if cmp -s "$agents_memory_template" "$claude_agents_memory_template" &&
   grep -Fq 'Never create `.project/` directories or documents' \
     "$PLX_CLAUDE/skills/agents-memory/SKILL.md"; then
  _pass "Claude and Codex agents-memory governance is identical"
else
  _fail "Claude and Codex agents-memory governance drift"
fi

if [ -f "$PLX_CLAUDE/skills/codex/SKILL.md" ] &&
   [ -f "$PLX_CODEX/skills/claude/SKILL.md" ] &&
   [ ! -e "$PLX_CODEX/skills/codex" ]; then
  _pass "opposite-host passthroughs are platform-correct"
else
  _fail "opposite-host passthrough contract is wrong"
fi

passthrough_overrides_ok=1
for skill in \
  "$PLX_CLAUDE/skills/codex/SKILL.md" \
  "$PLX_CLAUDE/skills/grok/SKILL.md" \
  "$PLX_CODEX/skills/claude/SKILL.md" \
  "$PLX_CODEX/skills/grok/SKILL.md"; do
  grep -Fq "An explicit user model or effort always replaces" "$skill" ||
    passthrough_overrides_ok=0
  grep -Fq -- "--model <model> --effort <effort>" "$skill" ||
    passthrough_overrides_ok=0
  grep -Fq "Do not" "$skill" || passthrough_overrides_ok=0
  grep -Fq "silently replace an explicit value" "$skill" ||
    passthrough_overrides_ok=0
done
if [ "$passthrough_overrides_ok" -eq 1 ]; then
  _pass "single-engine passthroughs preserve explicit model and effort overrides"
else
  _fail "single-engine passthrough override contract drift"
fi
if grep -Fq 'Defaults: `model=opus`, `effort=medium`.' \
     "$PLX_CODEX/skills/claude/SKILL.md"; then
  _pass "Codex-hosted Claude passthrough defaults Opus effort to medium"
else
  _fail "Codex-hosted Claude passthrough default effort drift"
fi

if grep -q 'Default to the existing \*\*ephemeral\*\*' "$PLX_CLAUDE/skills/codex/SKILL.md" &&
   grep -q 'plx-codex-thread start' "$PLX_CLAUDE/skills/codex/SKILL.md" &&
   grep -q 'plx-codex-thread resume' "$PLX_CLAUDE/skills/codex/SKILL.md" &&
   grep -q 'thread_id' "$PLX_CLAUDE/skills/codex/SKILL.md" &&
   ! grep -Rqi 'plx-codex-thread' \
     "$PLX_CLAUDE/skills/build" "$PLX_CLAUDE/skills/dev" \
     "$PLX_CLAUDE/skills/goal-spec" "$PLX_CLAUDE/skills/plan" \
     "$PLX_CLAUDE/skills/review"; then
  _pass "persistent Codex is explicit, resumable, and passthrough-only"
else
  _fail "persistent Codex skill contract drift"
fi

if [ "$(grep -c '^    code: grok$' "$PLX_CODEX/config/parallax.yaml")" -eq 2 ] &&
   [ "$(grep -c '^    code: grok$' "$PLX_CLAUDE/config/parallax.yaml")" -eq 2 ] &&
   [ "$(grep -c '^    code-fallback: codex$' "$PLX_CODEX/config/parallax.yaml")" -eq 2 ] &&
   [ "$(grep -c '^    code-fallback: codex$' "$PLX_CLAUDE/config/parallax.yaml")" -eq 2 ] &&
   [ "$(grep -c '^    review-security: \[claude\]$' "$PLX_CODEX/config/parallax.yaml")" -eq 2 ] &&
   [ "$(grep -c '^    review-security: \[codex\]$' "$PLX_CLAUDE/config/parallax.yaml")" -eq 2 ] &&
   ! grep -q '^    fix:' "$PLX_CODEX/config/parallax.yaml" &&
   ! grep -q '^    fix:' "$PLX_CLAUDE/config/parallax.yaml" &&
   [ "$(grep -c '\[claude\]' "$PLX_CODEX/config/parallax.yaml")" -eq 14 ] &&
   [ "$(grep -c '\[codex\]' "$PLX_CLAUDE/config/parallax.yaml")" -eq 14 ] &&
   ! grep -q '^    plan:' "$PLX_CODEX/config/parallax.yaml" &&
   ! grep -q '^    plan:' "$PLX_CLAUDE/config/parallax.yaml"; then
  _pass "host plans, opposite engine reviews, optional Grok writes, host fixes"
else
  _fail "engine polarity drift"
fi

if grep -qE 'fable-5|Codex review lanes|Standalone Codex plan critics|implementation critic \(codex' \
  "$PLX_ROOT/shared/prompts/engines.md"; then
  _fail "shared engine guidance contains Claude-host assumptions"
else
  _pass "shared engine guidance is host-neutral"
fi

if grep -q '(claude high) · fixes: host' "$PLX_CODEX/skills/review/SKILL.md" &&
   grep -q '(codex xhigh) · fixes: host' "$PLX_CLAUDE/skills/review/SKILL.md" &&
   ! grep -qiE 'fix lanes? on|fix-engine|fixes: grok' "$PLX_CODEX/skills/review/SKILL.md" "$PLX_CLAUDE/skills/review/SKILL.md" \
     "$PLX_CODEX/skills/dev/SKILL.md" "$PLX_CLAUDE/skills/dev/SKILL.md" &&
   ! grep -qE '(claude|codex) \+ grok' "$PLX_CODEX/skills/review/SKILL.md" "$PLX_CLAUDE/skills/review/SKILL.md"; then
  _pass "review examples preserve opposite-engine review and host-applied fixes"
else
  _fail "Codex review examples contradict configured polarity"
fi

if grep -Fq 'current change directly makes it obsolete' \
     "$PLX_ROOT/shared/prompts/reviewer-cleanup.md" &&
   grep -Fq 'small, behavior-preserving remedy is concrete' \
     "$PLX_ROOT/shared/prompts/reviewer-cleanup.md" &&
   grep -Fq 'unrelated pre-existing issues' \
     "$PLX_ROOT/shared/prompts/reviewer-cleanup.md" &&
   grep -Fq 'untouched-code findings with no causal link to the change' \
     "$PLX_ROOT/shared/prompts/reviewer-cleanup.md"; then
  _pass "cleanup review retires only debt made obsolete by the current change"
else
  _fail "cleanup debt-retirement boundary drift"
fi

eval_contract_ok=1
for package_host in "$PLX_CLAUDE:claude" "$PLX_CODEX:codex"; do
  package="${package_host%:*}"
  host="${package_host##*:}"
  for pipeline in plan build dev review; do
    skill="$package/skills/$pipeline/SKILL.md"
    grep -Fq "plx-eval begin --repo <repo> --pipeline $pipeline --host $host" "$skill" || eval_contract_ok=0
    grep -Fq 'plx-eval finish --repo <repo> --run-file <tmp>/.plx-eval-run' "$skill" || eval_contract_ok=0
    grep -Fq -- '--host-model <actual host model if known, otherwise unknown>' "$skill" || eval_contract_ok=0
    grep -Fq '<tmp>/.plx-eval-run' "$skill" || eval_contract_ok=0
    grep -Fq 'prompt files directly in `<tmp>`' "$skill" || eval_contract_ok=0
  done
done
if [ "$eval_contract_ok" -eq 1 ]; then
  _pass "plan/build/dev/review use grouped evaluation envelopes on both hosts"
else
  _fail "core pipeline evaluation envelope contract drift"
fi

parity_contract_ok=1
for host in claude codex; do
  package="$PLX_ROOT/plugins/$host/plx"
  grep -Fq 'code-fallback' "$package/skills/build/SKILL.md" || parity_contract_ok=0
  grep -Fq 'worktree becomes dirty' "$package/skills/build/SKILL.md" || parity_contract_ok=0
  grep -Fq 'reviewer-security' "$package/skills/review/SKILL.md" || parity_contract_ok=0
  grep -Fq 'Security: not run' "$package/skills/review/SKILL.md" || parity_contract_ok=0
  grep -Fq 'up to **3 questions per round**' "$package/skills/goal-spec/SKILL.md" || parity_contract_ok=0
  grep -Fq 'tool is not' "$package/skills/goal-spec/SKILL.md" || parity_contract_ok=0
done
if [ "$parity_contract_ok" -eq 1 ]; then
  _pass "Claude and Codex behavioral governance contracts are parallel"
else
  _fail "Claude and Codex behavioral governance contract drift"
fi

if ! grep -RqiE 'make the edit yourself|fix nits inline|one-liner you can.*edit|edit it yourself' \
     "$PLX_CLAUDE/skills/build" "$PLX_CODEX/skills/build" &&
   [ -z "$(grep -L 'Fix directly' "$PLX_CLAUDE/skills/review/SKILL.md" "$PLX_CODEX/skills/review/SKILL.md" \
     "$PLX_CLAUDE/skills/dev/SKILL.md" "$PLX_CODEX/skills/dev/SKILL.md")" ] &&
   ! grep -q -- '--rubric planner' "$PLX_CLAUDE/skills/goal-spec/SKILL.md" \
     "$PLX_CODEX/skills/goal-spec/SKILL.md"; then
  _pass "hosts delegate implementation, apply post-review fixes themselves, and author goal specs"
else
  _fail "host implementation or delegated goal-spec planning drift"
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
printf '#!/usr/bin/env bash\n' > "$SYNC_REPO/plugins/claude/plx/bin/plx-codex-thread"
chmod +x "$SYNC_REPO/plugins/claude/plx/bin/plx-codex-thread"
if "$SYNC_REPO/scripts/sync-shared.sh" --check >/dev/null 2>&1; then
  _pass "shared check permits the Claude-only Codex thread wrapper"
else
  _fail "shared check rejects the Claude-only Codex thread wrapper"
fi
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

for package in "$PLX_CLAUDE" "$PLX_CODEX"; do
  label="$(basename "$(dirname "$package")")"
  for tool in plx-engine plx-preflight plx-config plx-skill plx-link-claude plx-eval plx-clean-temp; do
    [ -x "$package/bin/$tool" ] && _pass "$label bin/$tool" || _fail "$label bin/$tool"
  done
  for rubric in engines planner plan-critic-implementation plan-critic-system worker reviewer-correctness reviewer-cleanup reviewer-structural reviewer-security; do
    [ -s "$package/prompts/$rubric.md" ] || _fail "$label missing rubric $rubric"
  done
done

if [ -x "$PLX_CLAUDE/bin/plx-codex-thread" ] &&
   [ -s "$PLX_CLAUDE/tools/codex-app-client/pyproject.toml" ] &&
   [ -s "$PLX_CLAUDE/tools/codex-app-client/uv.lock" ] &&
   [ ! -e "$PLX_CODEX/tools/codex-app-client" ]; then
  _pass "persistent Codex runtime is packaged only with Claude"
else
  _fail "persistent Codex runtime packaging drift"
fi

if grep -RqiE 'use subagents|spawn (a |an )?subagent' "$PLX_ROOT/plugins"; then
  _fail "a skill still instructs subagent orchestration"
else
  _pass "no skill instructs subagent orchestration"
fi
if find "$PLX_ROOT/plugins" -type d -name .parallax | grep -q .; then
  _fail "repo-local runtime state exists"
else
  _pass "no .parallax runtime state"
fi
if grep -RE '^[[:space:]]*[^#].*(danger-full-access|dangerously-bypass-approvals-and-sandbox|--yolo)' \
  "$PLX_ROOT/shared/bin" >/dev/null; then
  _fail "forbidden broad-permission flag in shared runtime"
else
  _pass "shared runtime rejects broad-permission patterns"
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
if grep -RqiE 'security finding \(hand off|drop.*security|security.*one line' \
     "$PLX_ROOT/plugins" "$PLX_ROOT/shared/prompts"; then
  _fail "review policy still drops security findings"
else
  _pass "security findings have an explicit review contract"
fi

# --------------------------------------------------------------------------- #
# Maintainer helper contracts
# --------------------------------------------------------------------------- #

_head "Maintainer helper contracts"
"$PLX_ROOT/tests/smoke-scripts.sh" codex >/dev/null 2>&1
smoke_rc=$?
"$PLX_ROOT/tests/smoke-scripts.sh" --with-engines codex >/dev/null 2>&1
smoke_extra_rc=$?
if [ "$smoke_rc" -eq 2 ] && [ "$smoke_extra_rc" -eq 2 ]; then
  _pass "smoke harness rejects positional package selectors"
else
  _fail "smoke harness silently accepted a positional package selector"
fi

explain_output="$("$PLX_ROOT/tests/explain-skill.sh" codex dev)"
if printf '%s\n' "$explain_output" | grep -q 'config key: dev' &&
   printf '%s\n' "$explain_output" | grep -q 'review-correctness: \[claude\]' &&
   printf '%s\n' "$explain_output" | grep -q '^preflight: plx-preflight'; then
  _pass "skill explanation resolves Codex bindings and preflight"
else
  _fail "skill explanation omitted Codex bindings or preflight"
fi

summary
