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

_head "Referenced \${CLAUDE_PLUGIN_ROOT} paths resolve"
while IFS= read -r ref; do
  [ -n "$ref" ] || continue
  rel="${ref#\$\{CLAUDE_PLUGIN_ROOT\}/}"
  if [ -e "$PLX_ROOT/$rel" ]; then _pass "$rel"; else _fail "dangling ref: $rel"; fi
done < <(grep -rhoE '\$\{CLAUDE_PLUGIN_ROOT\}/[A-Za-z0-9._/-]+' \
           "$PLX_ROOT/skills" "$PLX_ROOT/lib" "$PLX_ROOT/agents" 2>/dev/null | sort -u)

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
           "$PLX_ROOT/skills" "$PLX_ROOT/lib" 2>/dev/null | sort -u)

_head "Scripts present and executable"
for sc in codex-ro codex-rw grok-ro grok-rw make-review-prompt parallax-intake preflight; do
  assert_exec "scripts/$sc.sh"
done

_head "Prompt blocks present"
for b in plan code refine debug correctness synthesis coding-spec-template; do
  assert_file "prompts/$b.md"
done

summary
