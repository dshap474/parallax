#!/usr/bin/env bash
set -euo pipefail

RUN_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-dir) RUN_DIR="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -d "$RUN_DIR" ]] || { echo "run dir not found: $RUN_DIR" >&2; exit 2; }

echo "### Parallax run outputs"
find "$RUN_DIR" -maxdepth 2 -type f | sort | while read -r f; do
  bytes="$(wc -c < "$f" | tr -d ' ')"
  echo "- $f (${bytes} bytes)"
done
