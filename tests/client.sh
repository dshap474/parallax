#!/usr/bin/env bash
# Run vendored client unit and fake-server contracts without a model or credentials.
# Usage: bash tests/client.sh (requires uv; locked dependencies may need downloading).
set -euo pipefail

# --------------------------------------------------------------------------- #
# Isolated dependency environment
# --------------------------------------------------------------------------- #

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLIENT="$ROOT/plugins/claude/plx/tools/codex-app-client"
if ! command -v uv >/dev/null 2>&1; then
  echo "FAIL: client suite requires uv; no client behavior was verified" >&2
  exit 1
fi
WORK="$(mktemp -d "${TMPDIR:-/tmp}/plx-client-tests.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
export UV_PROJECT_ENVIRONMENT="$WORK/venv"
export PYTHONDONTWRITEBYTECODE=1

# --------------------------------------------------------------------------- #
# Suite entry point
# --------------------------------------------------------------------------- #

# Explicit directories prevent accidental collection of authenticated integration tests.
# --no-editable avoids build metadata in the source checkout; uv.lock remains untouched.
uv run --project "$CLIENT" --frozen --extra dev --no-editable \
  pytest -q -p no:cacheprovider --timeout=30 \
  "$CLIENT/tests/unit" "$CLIENT/tests/fake_server"
