#!/usr/bin/env bash
# Synchronize canonical Parallax runtime files into both installable plugins.
#
# Usage:
#   scripts/sync-shared.sh          # update package-local copies
#   scripts/sync-shared.sh --check  # report drift without writing
set -euo pipefail

# --------------------------------------------------------------------------- #
# Paths and arguments
# --------------------------------------------------------------------------- #

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-sync}"

case "$MODE" in
  sync|--check) ;;
  *) echo "usage: scripts/sync-shared.sh [--check]" >&2; exit 2 ;;
esac

# --------------------------------------------------------------------------- #
# Synchronization
# --------------------------------------------------------------------------- #

sync_tree() {
  local source="$1" destination="$2" relative source_file destination_file drift=0

  while IFS= read -r source_file; do
    relative="${source_file#"$source/"}"
    destination_file="$destination/$relative"
    if [ ! -f "$destination_file" ] || ! cmp -s "$source_file" "$destination_file"; then
      if [ "$MODE" = "--check" ]; then
        echo "drift: ${destination_file#"$ROOT/"}" >&2
        drift=1
      else
        mkdir -p "$(dirname "$destination_file")"
        cp "$source_file" "$destination_file"
      fi
    fi
  done < <(find "$source" -type f | sort)

  return "$drift"
}

rc=0
for package in "$ROOT/plugins/claude/plx" "$ROOT/plugins/codex/plx"; do
  sync_tree "$ROOT/shared/bin" "$package/bin" || rc=1
  sync_tree "$ROOT/shared/prompts" "$package/prompts" || rc=1
  if [ ! -f "$package/LICENSE" ] || ! cmp -s "$ROOT/LICENSE" "$package/LICENSE"; then
    if [ "$MODE" = "--check" ]; then
      echo "drift: ${package#"$ROOT/"}/LICENSE" >&2
      rc=1
    else
      cp "$ROOT/LICENSE" "$package/LICENSE"
    fi
  fi
done

if [ "$MODE" = "--check" ] && [ "$rc" -eq 0 ]; then
  echo "shared runtime copies are current"
fi
exit "$rc"
