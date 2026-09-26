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
if [ "$claude_version" = "0.5.34" ] && [ "$claude_version" = "$codex_version" ] &&
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

_head "Thirteen host-native skills per package"
claude_count="$(find "$PLX_CLAUDE/skills" -mindepth 2 -maxdepth 2 -name SKILL.md | wc -l | tr -d ' ')"
codex_count="$(find "$PLX_CODEX/skills" -mindepth 2 -maxdepth 2 -name SKILL.md | wc -l | tr -d ' ')"
[ "$claude_count" = 13 ] && _pass "Claude skills: 13" || _fail "Claude skills: $claude_count"
[ "$codex_count" = 13 ] && _pass "Codex skills: 13" || _fail "Codex skills: $codex_count"

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

passthrough_overrides_ok=1
for skill in \
  "$PLX_CLAUDE/skills/codex/SKILL.md" \
  "$PLX_CODEX/skills/claude/SKILL.md"; do
  grep -Fq "An explicit user model or effort replaces" "$skill" ||
    passthrough_overrides_ok=0
  grep -Fq -- "--model <model> --effort <effort>" "$skill" ||
    passthrough_overrides_ok=0
  grep -Fq "Do not" "$skill" || passthrough_overrides_ok=0
  grep -Fq "silently replace an explicit value" "$skill" ||
    passthrough_overrides_ok=0
done
for skill in \
  "$PLX_CLAUDE/skills/grok/SKILL.md" \
  "$PLX_CODEX/skills/grok/SKILL.md"; do
  grep -Fq "An explicit user model always replaces" "$skill" ||
    passthrough_overrides_ok=0
  grep -Fq 'default for models other than `grok-4.6`' "$skill" ||
    passthrough_overrides_ok=0
  grep -Fq "pinning Grok 4.6 to medium" "$skill" ||
    passthrough_overrides_ok=0
  grep -Fq -- "--model <model> --effort <effort>" "$skill" ||
    passthrough_overrides_ok=0
done
for skill in \
  "$PLX_CLAUDE/skills/devin/SKILL.md" \
  "$PLX_CODEX/skills/devin/SKILL.md"; do
  grep -Fq 'Default: `model=swe-2-high`.' "$skill" ||
    passthrough_overrides_ok=0
  grep -Fq -- '--mode full-access' "$skill" || passthrough_overrides_ok=0
  grep -Fq 'Never pass `--effort`.' "$skill" || passthrough_overrides_ok=0
  grep -Fq 'full host access' "$skill" || passthrough_overrides_ok=0
  grep -Fq 'Repository-native Devin hooks, MCP servers, rules, and skills can' "$skill" ||
    passthrough_overrides_ok=0
  grep -Fq 'Only exit 4 allows automatic recovery: at most two retries' "$skill" ||
    passthrough_overrides_ok=0
  grep -Fq 'If a side effect is ambiguous or replay could duplicate an action, stop' "$skill" ||
    passthrough_overrides_ok=0
  grep -Fq 'A failed reconciliation command stops recovery.' "$skill" ||
    passthrough_overrides_ok=0
  grep -Fq -- '--out <tmp>/attempt-1.out --log <tmp>/attempt-1.log' "$skill" ||
    passthrough_overrides_ok=0
  if grep -Fq 'A nonzero exit ends this skill. Do not retry' "$skill"; then
    passthrough_overrides_ok=0
  fi
done
if [ "$passthrough_overrides_ok" -eq 1 ]; then
  _pass "single-engine passthroughs preserve overrides and Devin uses explicit full access"
else
  _fail "single-engine passthrough override contract drift"
fi
if grep -Fq 'Defaults: `model=claude-opus-5-5`, `effort=medium`.' \
     "$PLX_CODEX/skills/claude/SKILL.md"; then
  _pass "Codex-hosted Claude passthrough defaults Opus 5.5 effort to medium"
else
  _fail "Codex-hosted Claude passthrough default effort drift"
fi

claude_host_boundary_ok=1
for skill in plan review simplify; do
  grep -Fq 'narrowly scoped host approval' \
    "$PLX_CODEX/skills/$skill/SKILL.md" || claude_host_boundary_ok=0
done
if [ "$claude_host_boundary_ok" -eq 1 ] &&
   grep -Fq -- '--claude-passthrough-full-access' "$PLX_CODEX/skills/claude/SKILL.md" &&
   grep -Fq 'if Claude works in a local terminal' "$PLX_ROOT/shared/bin/plx-engine"; then
  _pass "Codex-hosted Claude passthrough has full access; pipeline calls preserve OAuth access"
else
  _fail "Codex-hosted Claude access boundary drift"
fi

if grep -q 'Default to the existing \*\*ephemeral\*\*' "$PLX_CLAUDE/skills/codex/SKILL.md" &&
   grep -q 'plx-codex-thread start' "$PLX_CLAUDE/skills/codex/references/persistence.md" &&
   grep -q 'plx-codex-thread resume' "$PLX_CLAUDE/skills/codex/references/persistence.md" &&
   grep -Fq -- '--codex-passthrough-full-access' "$PLX_CLAUDE/skills/codex/SKILL.md" &&
   grep -q 'thread_id' "$PLX_CLAUDE/skills/codex/references/persistence.md" &&
   ! grep -Rqi 'plx-codex-thread' \
     "$PLX_CLAUDE/skills/build" "$PLX_CLAUDE/skills/dev" \
     "$PLX_CLAUDE/skills/plan" \
     "$PLX_CLAUDE/skills/review" "$PLX_CLAUDE/skills/simplify" \
     "$PLX_CLAUDE/skills/kiss"; then
  _pass "persistent Codex is explicit, resumable, and passthrough-only"
else
  _fail "persistent Codex skill contract drift"
fi

simplify_defaults_ok=1
for role in reuse simplification efficiency altitude; do
  grep -qx "    simplify-$role: \[grok\]" "$PLX_CODEX/config/parallax.yaml" ||
    simplify_defaults_ok=0
  grep -qx "    simplify-$role: \[grok\]" "$PLX_CLAUDE/config/parallax.yaml" ||
    simplify_defaults_ok=0
done

if [ "$simplify_defaults_ok" -eq 1 ] &&
   ! grep -Eq '^  (plan|dev):' "$PLX_CODEX/config/parallax.yaml" "$PLX_CLAUDE/config/parallax.yaml"; then
  _pass "only Simplify uses configured engine bindings"
else
  _fail "obsolete Plan or Dev bindings remain"
fi

simplify_contract_ok=1
for package in "$PLX_CLAUDE" "$PLX_CODEX"; do
  skill="$package/skills/simplify/SKILL.md"
  grep -Fq 'default is four `grok-4.6` lanes at `medium`' "$skill" || simplify_contract_ok=0
  grep -Fq 'Run exactly these read-only roles' "$skill" || simplify_contract_ok=0
  grep -Fq 'Do not create repository runtime state' "$skill" || simplify_contract_ok=0
  grep -Fq -- '--model <model>' "$skill" || simplify_contract_ok=0
  grep -Fq 'Never weaken requirements' "$skill" || simplify_contract_ok=0
  for rubric in reuse simplification efficiency altitude; do
    grep -Fq "simplify-$rubric" "$skill" || simplify_contract_ok=0
  done
done
if [ "$simplify_contract_ok" -eq 1 ]; then
  _pass "Simplify keeps four Grok 4.6 Medium dimensions and host synthesis"
else
  _fail "Simplify fixed-shape contract drift"
fi

kiss_principles_ok=1
for package in "$PLX_CLAUDE" "$PLX_CODEX"; do
  skill="$package/skills/kiss/SKILL.md"
  grep -Fq '# KISS principles' "$skill" || kiss_principles_ok=0
  grep -Fq "Load the user's KISS principles into the current context" "$skill" || kiss_principles_ok=0
  grep -Fq 'Simple means the smallest complete solution, not the fewest lines.' "$skill" || kiss_principles_ok=0
  grep -Fq 'Stop when the simplest complete solution works.' "$skill" || kiss_principles_ok=0
  ! grep -Eq 'plx-engine|plx-eval|--mode (ro|rw)' "$skill" || kiss_principles_ok=0
done
if [ "$kiss_principles_ok" -eq 1 ]; then
  _pass "KISS is a context-only principles skill"
else
  _fail "KISS principles contract drift"
fi

if grep -Eq 'plx-engine|plx-eval|--mode (ro|rw)' \
     "$PLX_CLAUDE/skills/orchestrate/SKILL.md" \
     "$PLX_CODEX/skills/orchestrate/SKILL.md"; then
  _fail "Orchestrate must remain context-only"
else
  _pass "Orchestrate is context-only"
fi

if grep -qE 'Codex review lanes|Standalone Codex plan critics|implementation critic \(codex' \
  "$PLX_ROOT/shared/prompts/engines.md"; then
  _fail "shared engine guidance contains Claude-host assumptions"
else
  _pass "shared engine guidance is host-neutral"
fi

# Check launch contracts and cross-host copies; prose wording is not a runtime API.
review_contract_ok=1
for package in "$PLX_CLAUDE" "$PLX_CODEX"; do
  skill="$package/skills/review/SKILL.md"
  for role in correctness cleanup structural security; do
    grep -Fq "reviewer-$role" "$skill" || review_contract_ok=0
  done
  for token in '--mode ro' '--model <model> --effort <effort>' 'grok-4.5' 'medium'; do
    grep -Fq -- "$token" "$skill" || review_contract_ok=0
  done
done
if [ "$review_contract_ok" -eq 1 ]; then
  _pass "standalone review supplies core and security roles with explicit read-only launch settings"
else
  _fail "standalone review launch contract drift"
fi

if grep -Fq 'In change reviews, pre-existing complexity is in scope only when the change directly' \
     "$PLX_ROOT/shared/prompts/reviewer-cleanup.md" &&
   grep -Fq 'concrete, behavior-preserving remedy' \
     "$PLX_ROOT/shared/prompts/reviewer-cleanup.md" &&
   grep -Fq 'unrelated pre-existing issues' \
     "$PLX_ROOT/shared/prompts/reviewer-cleanup.md" &&
   grep -Fq 'In a whole-file audit, existing issues within' \
     "$PLX_ROOT/shared/prompts/reviewer-cleanup.md"; then
  _pass "cleanup review distinguishes change reviews from whole-file audits"
else
  _fail "cleanup debt-retirement boundary drift"
fi

eval_contract_ok=1
for package_host in "$PLX_CLAUDE:claude" "$PLX_CODEX:codex"; do
  package="${package_host%:*}"
  host="${package_host##*:}"
  for skill in "$package"/skills/*/SKILL.md; do
    skill_name="$(basename "$(dirname "$skill")")"
    if [ "$skill_name" = kiss ] || [ "$skill_name" = orchestrate ] || [ "$skill_name" = init ]; then
      ! grep -Fq 'plx-eval finish' "$skill" || eval_contract_ok=0
      continue
    fi
    grep -Fq "plx-eval finish --skill $skill_name --host $host" "$skill" || eval_contract_ok=0
    ! grep -Fq 'plx-eval begin' "$skill" || eval_contract_ok=0
    ! grep -Fq '.plx-eval-run' "$skill" || eval_contract_ok=0
  done
  for pipeline in plan build dev review simplify; do
    skill="$package/skills/$pipeline/SKILL.md"
    grep -Fq -- '--run-dir <tmp>' "$skill" || eval_contract_ok=0
  done
done
if [ "$eval_contract_ok" -eq 1 ]; then
  _pass "operational skills finish traces and grouped pipelines use temp-directory identity"
else
  _fail "skill trace capture contract drift"
fi

if python3 - "$PLX_ROOT" <<'PY_CONTRACT'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
errors = []
for host, model, effort in (("claude", "claude-opus-5-5", "medium"), ("codex", "gpt-6-sol", "high")):
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
                  "Baseline snapshots:", "Verification suite:", f"--require-{host}"):
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
        body = re.sub(r"For Grok (?:calls and preflight|preflight and review calls),.*?active\.", "HOST_BOUNDARY", body, flags=re.S)
        body = body.replace("<plugin-root>/bin/", "").replace("$plx:", "/plx:")
        if name == "build":
            body = body.replace("gpt-6-sol", "claude-opus-5-5").replace("high", "medium")
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

grok_sandbox_contract_ok=1
for host in claude codex; do
  package="$PLX_ROOT/plugins/$host/plx"
  grep -Fq '[PLX:GROK FAILED]' "$package/skills/grok/SKILL.md" || grok_sandbox_contract_ok=0
  grep -Fq 'Do not perform the task in the host session' "$package/skills/grok/SKILL.md" || grok_sandbox_contract_ok=0
done
if [ "$grok_sandbox_contract_ok" -eq 1 ]; then
  _pass "Grok passthroughs fail closed"
else
  _fail "Grok workspace preflight or fail-closed contract drift"
fi

prompt_constraints_ok=1
for host in claude codex; do
  package="$PLX_ROOT/plugins/$host/plx"
  # Guard the intentional relaxation without pinning replacement prose.
  if grep -qiE 'three tool calls|exactly three calls|WITHOUT reading file contents|do NOT read the code under review|always request narrowly scoped host approval' \
      "$package"/skills/*/SKILL.md; then
    prompt_constraints_ok=0
  fi
  if grep -qE 'Return exactly|Final Report Format|recursive delegation' \
      "$package/prompts/worker.md" "$package/prompts/build-worker.md" \
      "$package/skills/plan/references/spec-template.md"; then
    prompt_constraints_ok=0
  fi
  for skill in plan; do
    for field in '## Draft plan' '### Original request' '### Confirmed decisions' '### Candidate plan'; do
      grep -Fq "$field" "$package/skills/$skill/SKILL.md" || prompt_constraints_ok=0
    done
  done
done
if [ "$prompt_constraints_ok" -eq 1 ]; then
  _pass "neutral critic briefs remain structured while host mechanics and reports stay flexible"
else
  _fail "critic brief or prompt simplification contract drift"
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
  for tool in plx-engine plx-preflight plx-config plx-skill plx-link-claude plx-eval plx-clean-temp; do
    [ -x "$package/bin/$tool" ] && _pass "$label bin/$tool" || _fail "$label bin/$tool"
  done
  for rubric in engines planner plan-critic worker build-worker reviewer-correctness reviewer-cleanup reviewer-structural reviewer-security simplify-reuse simplify-simplification simplify-efficiency simplify-altitude; do
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
     ! grep -Fq '[[ "$BUILD_WRITER_FULL_ACCESS" -eq 1 ]]' "$PLX_ROOT/shared/bin/plx-engine" ||
     ! grep -Fq '[[ "$RUBRIC" == "worker" || "$RUBRIC" == "build-worker" ]]' "$PLX_ROOT/shared/bin/plx-engine" ||
     ! grep -Fq '[[ "$ENGINE" == "claude" && "$MODE" == "rw" && -z "$RUBRIC" && "$BUILD_WRITER_FULL_ACCESS" -eq 0 ]]' "$PLX_ROOT/shared/bin/plx-engine" ||
     ! grep -Fq '[[ "$ENGINE" == "codex" && "$MODE" == "rw" && -z "$RUBRIC" && "$BUILD_WRITER_FULL_ACCESS" -eq 0 ]]' "$PLX_ROOT/shared/bin/plx-engine" ||
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
if printf '%s\n' "$explain_output" | grep -q 'config key: (none' &&
   printf '%s\n' "$explain_output" | grep -q 'plx-skill plan' &&
   printf '%s\n' "$explain_output" | grep -q 'plx-skill build' &&
   printf '%s\n' "$explain_output" | grep -q 'plx-skill review'; then
  _pass "skill explanation shows Dev composition"
else
  _fail "skill explanation omitted Dev composition"
fi

summary
