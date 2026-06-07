#!/usr/bin/env bash
set -euo pipefail

REPO=""
REQUIRE_CODEX=0
OPTIONAL_GROK=0
REQUIRE_GROK=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --require-codex) REQUIRE_CODEX=1; shift ;;
    --optional-grok) OPTIONAL_GROK=1; shift ;;
    --require-grok) REQUIRE_GROK=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$REPO" ]] || { echo "--repo required" >&2; exit 2; }
[[ -d "$REPO" ]] || { echo "repo not found: $REPO" >&2; exit 2; }
REPO="$(cd "$REPO" && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/parallax-preflight.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
mkdir -p "$TMP_DIR"/{prompts,outputs,logs}

CODEX_OK=0
GROK_OK=0
STATUS=0

print_log_tail() {
  local log_file="$1"
  [[ -s "$log_file" ]] || return 0
  echo "  log tail:"
  sed -n '1,20p' "$log_file" | sed 's/^/  > /'
}

probe_codex() {
  if ! command -v codex >/dev/null 2>&1; then
    echo "- codex: missing"
    return 1
  fi

  printf '%s\n' "reply OK" > "$TMP_DIR/prompts/codex-probe.md"
  if "$SCRIPT_DIR/codex-ro.sh" \
    --repo "$REPO" \
    --prompt "$TMP_DIR/prompts/codex-probe.md" \
    --out "$TMP_DIR/outputs/codex-probe.md" \
    --log "$TMP_DIR/logs/codex-probe.log" \
    --effort low >/dev/null && [[ -s "$TMP_DIR/outputs/codex-probe.md" ]]; then
    echo "- codex: ok"
    CODEX_OK=1
    return 0
  fi

  echo "- codex: probe failed"
  print_log_tail "$TMP_DIR/logs/codex-probe.log"
  return 1
}

probe_grok() {
  if ! command -v grok >/dev/null 2>&1; then
    echo "- grok: missing"
    return 1
  fi

  printf '%s\n' "reply OK" > "$TMP_DIR/prompts/grok-probe.md"
  if "$SCRIPT_DIR/grok-ro.sh" \
    --repo "$REPO" \
    --prompt "$TMP_DIR/prompts/grok-probe.md" \
    --out "$TMP_DIR/outputs/grok-probe.txt" \
    --log "$TMP_DIR/logs/grok-probe.log" \
    --effort low >/dev/null && [[ -s "$TMP_DIR/outputs/grok-probe.txt" ]]; then
    echo "- grok: ok"
    GROK_OK=1
    return 0
  fi

  echo "- grok: probe failed or empty output"
  print_log_tail "$TMP_DIR/logs/grok-probe.log"
  return 1
}

echo "### Parallax preflight"
echo "- repo: $REPO"
echo "- temp_artifacts: ephemeral"

if [[ "$REQUIRE_CODEX" -eq 1 ]]; then
  probe_codex || STATUS=1
fi

if [[ "$REQUIRE_GROK" -eq 1 ]]; then
  probe_grok || STATUS=1
elif [[ "$OPTIONAL_GROK" -eq 1 ]]; then
  probe_grok || true
fi

echo "- preflight_ok: $([[ "$STATUS" -eq 0 ]] && echo yes || echo no)"
echo "- codex_ok: $([[ "$CODEX_OK" -eq 1 ]] && echo yes || echo no)"
echo "- grok_ok: $([[ "$GROK_OK" -eq 1 ]] && echo yes || echo no)"
exit "$STATUS"
