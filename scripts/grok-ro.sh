#!/usr/bin/env bash
set -euo pipefail

EFFORT="high"
REPO=""
PROMPT=""
OUT=""
LOG=""
STDOUT=0
TMP_DIR=""

cleanup() {
  if [[ -n "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --prompt) PROMPT="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --log) LOG="$2"; shift 2 ;;
    --stdout) STDOUT=1; shift ;;
    --effort) EFFORT="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -d "$REPO" ]] || { echo "repo not found: $REPO" >&2; exit 2; }
[[ -s "$PROMPT" ]] || { echo "prompt missing/empty: $PROMPT" >&2; exit 2; }
if [[ "$STDOUT" -eq 1 ]]; then
  TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/parallax-grok.XXXXXX")"
  OUT="$TMP_DIR/output.txt"
  LOG="$TMP_DIR/grok.log"
else
  [[ -n "$OUT" ]] || { echo "--out required" >&2; exit 2; }
  [[ -n "$LOG" ]] || { echo "--log required" >&2; exit 2; }
fi

mkdir -p "$(dirname "$OUT")" "$(dirname "$LOG")"

if ! grok --cwd "$REPO" --permission-mode plan --reasoning-effort "$EFFORT" \
  --prompt-file "$PROMPT" > "$OUT" 2>"$LOG"; then
  echo "grok invocation failed" >&2
  [[ -s "$LOG" ]] && sed -n '1,40p' "$LOG" >&2
  exit 1
fi

[[ -s "$OUT" ]] || { echo "grok produced empty output: $OUT" >&2; exit 1; }

if [[ "$STDOUT" -eq 1 ]]; then
  cat "$OUT"
else
  echo "OK grok-ro out=$OUT log=$LOG"
fi
