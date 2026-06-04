#!/usr/bin/env bash
# Mirror the canonical reference docs into each skill's own references/ dir.
#
# Why: ${CLAUDE_PLUGIN_ROOT} is unreliable inside SKILL.md body text (claude-code
# issue #9354), so a skill cannot point at one shared references/ at the plugin root.
# Each skill therefore carries its OWN copy. This script keeps those copies DRY by
# treating _source/references as the single source of truth. Run it before committing
# after any change to _source/references.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/_source/references"

[ -d "$SRC" ] || { echo "error: $SRC not found" >&2; exit 1; }

for skill in "$ROOT"/skills/*/; do
  [ -d "$skill" ] || continue
  dst="$skill/references"
  mkdir -p "$dst"
  rm -f "$dst"/*.md
  cp "$SRC"/*.md "$dst"/
  echo "synced -> $dst"
done

echo "done."
