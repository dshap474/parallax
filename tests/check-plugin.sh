#!/usr/bin/env bash
# Static integrity of the Parallax plugin. No model calls — pure wiring checks.
# Catches the drift this plugin is prone to: dangling ${CLAUDE_PLUGIN_ROOT} paths,
# config keys a skill references but the YAML lacks, missing agents/scripts.
set -uo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

_head "Manifests are valid JSON"
for m in .claude-plugin/plugin.json .claude-plugin/marketplace.json; do
  if [ -f "$PLX_ROOT/$m" ]; then
    if python3 -m json.tool "$PLX_ROOT/$m" >/dev/null 2>&1; then _pass "$m"; else _fail "invalid JSON: $m"; fi
  else
    _fail "missing: $m"
  fi
done

_head "Every skill has frontmatter name"
for s in "$PLX_ROOT"/skills/*/SKILL.md; do
  rel="${s#$PLX_ROOT/}"
  if grep -qE '^name:[[:space:]]*"?plx::' "$s"; then _pass "$rel"; else _fail "no plx:: name in $rel"; fi
done

_head "No \${CLAUDE_PLUGIN_ROOT} in skills/agents (unreliable in prose — bin/ tools are on PATH)"
if grep -rq 'CLAUDE_PLUGIN_ROOT' "$PLX_ROOT/skills" "$PLX_ROOT/agents" 2>/dev/null; then
  _fail "a skill or agent still uses \${CLAUDE_PLUGIN_ROOT}"
else
  _pass "skills and agents reference bin/ tools by bare name only"
fi

_head "plx-* tools referenced by skills/agents exist in bin/"
while IFS= read -r tool; do
  [ -n "$tool" ] || continue
  if [ -x "$PLX_ROOT/bin/$tool" ]; then _pass "bin/$tool"; else _fail "referenced tool missing: bin/$tool"; fi
done < <(grep -rhoE '`plx-[a-z*-]+' "$PLX_ROOT/skills" "$PLX_ROOT/agents" 2>/dev/null | tr -d '`' | grep -E '^plx-[a-z]+(-[a-z]+)*$' | sort -u)

_head "Config keys referenced by skills exist in parallax.yaml"
YAML="$PLX_ROOT/config/parallax.yaml"
while IFS= read -r line; do
  key="$(printf '%s' "$line" | sed -E 's/.*key `([a-z-]+)`.*/\1/')"
  [ -n "$key" ] || continue
  if grep -qE "^  ${key}:" "$YAML"; then _pass "config key: $key"; else _fail "skill references missing config key: $key"; fi
done < <(grep -rhoE 'key `[a-z-]+`' "$PLX_ROOT"/skills/*/SKILL.md 2>/dev/null | sort -u)

_head "Referenced plx:<engine>-<role> subagents have agent files"
while IFS= read -r sub; do
  name="${sub#plx:}"
  if [ -f "$PLX_ROOT/agents/$name.md" ]; then _pass "agent: $name.md"; else _fail "missing agent file: agents/$name.md"; fi
done < <(grep -rhoE 'plx:(claude|codex|grok)-(reviewer|worker)' \
           "$PLX_ROOT/skills" 2>/dev/null | sort -u)

_head "Engine API tools present and executable"
for sc in plx-codex-ro plx-codex-rw plx-grok-ro plx-grok-rw plx-preflight plx-config plx-skill; do
  assert_exec "bin/$sc"
done

_head "Base prompts (reference storage, not loaded at runtime)"
if [ -d "$PLX_ROOT/base-prompts" ]; then
  for b in "$PLX_ROOT"/base-prompts/*.md; do
    [ -e "$b" ] || break
    _pass "base prompt: ${b##*/}"
  done
else
  _pass "base-prompts/ absent (rebuilt in scaffold phase — see .project/PLX.md)"
fi

_head "Skills are self-contained (no pointers into lib/, prompts/, scripts/, or router.md)"
if grep -rqE 'lib/(pipeline|engines)\.md|prompts/|scripts/|router\.md' "$PLX_ROOT"/skills/*/SKILL.md; then
  _fail "a skill still points at lib/, prompts/, scripts/, or router.md"
else
  _pass "no skill references lib/, prompts/, scripts/, or router.md"
fi

summary
