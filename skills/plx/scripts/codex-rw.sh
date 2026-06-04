#!/usr/bin/env bash
set -euo pipefail

# Write-capable Codex wrapper. Unlike codex-ro.sh, this lets Codex EDIT files in
# the target repo. It is used only when parallax.yaml assigns a non-Claude engine
# to the writer (`code`) role. Safety: scoped `workspace-write` sandbox (writes
# confined to --cwd, no network, no full-access), --ignore-user-config so the
# user's global Codex config can never widen the sandbox. Never danger-full-access,
# never --dangerously-bypass-approvals-and-sandbox.

MODEL="gpt-5.5"
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
    --model) MODEL="$2"; shift 2 ;;
    --effort) EFFORT="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -d "$REPO" ]] || { echo "repo not found: $REPO" >&2; exit 2; }
[[ -s "$PROMPT" ]] || { echo "prompt missing/empty: $PROMPT" >&2; exit 2; }
if [[ "$STDOUT" -eq 1 ]]; then
  TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/parallax-codex-rw.XXXXXX")"
  OUT="$TMP_DIR/output.md"
  LOG="$TMP_DIR/codex.log"
else
  [[ -n "$OUT" ]] || { echo "--out required" >&2; exit 2; }
  [[ -n "$LOG" ]] || { echo "--log required" >&2; exit 2; }
fi

mkdir -p "$(dirname "$OUT")" "$(dirname "$LOG")"

if ! codex exec --ignore-user-config --sandbox workspace-write --skip-git-repo-check \
  -C "$REPO" -m "$MODEL" -c model_reasoning_effort="$EFFORT" --ephemeral \
  -o "$OUT" - < "$PROMPT" > "$LOG" 2>&1; then
  echo "codex invocation failed" >&2
  [[ -s "$LOG" ]] && sed -n '1,40p' "$LOG" >&2
  exit 1
fi

[[ -s "$OUT" ]] || { echo "codex produced empty output: $OUT" >&2; exit 1; }

if [[ "$STDOUT" -eq 1 ]]; then
  cat "$OUT"
else
  echo "OK codex-rw out=$OUT log=$LOG"
fi
