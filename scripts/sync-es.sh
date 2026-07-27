#!/usr/bin/env bash
# Sync all Spanish-edition LaTeX sources into LILT TM (see scripts/es-sources.txt).
#
# Env:
#   LILT_CMD  Command prefix to invoke lilt (default: lilt on PATH).
#             Example: LILT_CMD='uv run --directory /path/to/lilt lilt'
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

LILT_CMD="${LILT_CMD:-lilt}"
SOURCES_FILE="$ROOT/scripts/es-sources.txt"

log() { printf '+ %s\n' "$*"; }

run_lilt() {
  # shellcheck disable=SC2086
  $LILT_CMD --work-dir "$ROOT" "$@"
}

if [[ ! -f "$SOURCES_FILE" ]]; then
  echo "error: missing $SOURCES_FILE" >&2
  exit 1
fi

if [[ "$LILT_CMD" == "lilt" ]] && ! command -v lilt >/dev/null 2>&1; then
  echo "error: lilt not on PATH; set LILT_CMD" >&2
  exit 1
fi

while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  [[ -z "$line" || "$line" == \#* ]] && continue
  if [[ ! -f "$ROOT/$line" ]]; then
    echo "error: source not found: $line (update scripts/es-sources.txt?)" >&2
    exit 1
  fi
  log "lilt pipeline sync $line"
  run_lilt pipeline sync "$line"
done <"$SOURCES_FILE"

log "sync-es complete"
