#!/usr/bin/env bash
# Build the Spanish xv6 book PDF from committed LILT TM (no LLM calls).
#
# Sources: scripts/es-sources.txt (SSOT). Root chapters are lineref'd into
# i18n/pdf/latex.out/; book.tex is the driver; fig/* are built into i18n/build/
# when present in the list (not lineref'd).
#
# Env:
#   LILT_CMD  Command prefix to invoke lilt (default: lilt on PATH).
#             Example: LILT_CMD='uv run --directory /path/to/lilt lilt'
#
# Notes:
#   - lineref "cannot find pat" warnings are OS↔book drift; they do not abort.
#   - pdflatex failure dumps the tail of i18n/pdf/book.log and exits non-zero.
#
# Output: i18n/book-es.pdf
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

LILT_CMD="${LILT_CMD:-lilt}"
SOURCES_FILE="$ROOT/scripts/es-sources.txt"
BUILD_DIR="$ROOT/i18n/build"
PDF_DIR="$ROOT/i18n/pdf"
LINEREF_OUT="$PDF_DIR/latex.out"
SRC_DIR="$ROOT/xv6-riscv-src"
BOOKLET_FMT="$ROOT/xv6-riscv-src-booklet/fmt"

log() { printf '+ %s\n' "$*"; }

# Always pin LILT to this book tree (needed when LILT_CMD uses `uv --directory` on another repo).
run_lilt() {
  # shellcheck disable=SC2086
  $LILT_CMD --work-dir "$ROOT" "$@"
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: required command not found: $1" >&2
    exit 1
  fi
}

# path/to/foo.tex -> path__to__foo (LILT namespace encoding)
tex_to_ns() {
  local p="$1"
  p="${p%.tex}"
  echo "${p//\//__}"
}

load_sources() {
  SOURCES=()
  if [[ ! -f "$SOURCES_FILE" ]]; then
    echo "error: missing $SOURCES_FILE" >&2
    exit 1
  fi
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" || "$line" == \#* ]] && continue
    SOURCES+=("$line")
  done <"$SOURCES_FILE"
  if [[ ${#SOURCES[@]} -eq 0 ]]; then
    echo "error: no sources in $SOURCES_FILE" >&2
    exit 1
  fi
}

if [[ "$LILT_CMD" == "lilt" ]]; then
  need_cmd lilt
fi
need_cmd pdflatex
need_cmd bibtex
need_cmd python3
need_cmd git

load_sources

# --- 1. LILT pipeline build (TM → Spanish .tex) ---
# fig/* are synced (es-sources.txt) but not built here: PDF staging symlinks
# repo fig/ (English). Empty fig__* namespaces fail LILT build (fail-closed).
mkdir -p "$BUILD_DIR"
for rel in "${SOURCES[@]}"; do
  case "$rel" in
    fig/*) continue ;;
  esac
  if [[ ! -f "$ROOT/$rel" ]]; then
    echo "error: source not found: $rel" >&2
    exit 1
  fi
  ns="$(tex_to_ns "$rel")"
  out="i18n/build/${rel}"
  mkdir -p "$(dirname "$ROOT/$out")"
  log "lilt pipeline build ${ns} ${rel} ${out}"
  run_lilt pipeline build "${ns}" "${rel}" "${out}"
done

# --- 2. xv6 source + booklet fmt (for lineref) ---
if [[ ! -d "$SRC_DIR" ]]; then
  log "clone mit-pdos/xv6-riscv → xv6-riscv-src"
  git clone --depth 1 https://github.com/mit-pdos/xv6-riscv.git "$SRC_DIR"
fi
if [[ ! -d "$BOOKLET_FMT" ]]; then
  log "build xv6-riscv-src-booklet/fmt"
  make -C "$ROOT/xv6-riscv-src-booklet"
fi

# --- 3. lineref on root chapters only (not book.tex, not fig/*) ---
mkdir -p "$LINEREF_OUT"
for rel in "${SOURCES[@]}"; do
  case "$rel" in
    book.tex|fig/*) continue ;;
  esac
  name="${rel%.tex}"
  name="${name##*/}"
  log "lineref ${name}.tex"
  # lineref pattern misses are expected noise (OS↔book drift); do not abort.
  python3 "$ROOT/lineref" \
    "$BUILD_DIR/${name}.tex" \
    "$SRC_DIR" \
    "$BOOKLET_FMT" \
    >"$LINEREF_OUT/${name}.tex" || true
done

# --- 4. Staging tree for pdflatex ---
mkdir -p "$PDF_DIR"
ln -sfn "$ROOT/fig" "$PDF_DIR/fig"
ln -sfn "$ROOT/font" "$PDF_DIR/font"
ln -sfn "$ROOT/book.bib" "$PDF_DIR/book.bib"

# Prefer built Spanish book.tex; ensure tikz (gnuplot-lua-tikz often missing in CI/minimal TeX).
python3 - "$BUILD_DIR/book.tex" "$PDF_DIR/book.tex" <<'PY'
import pathlib
import sys

src = pathlib.Path(sys.argv[1])
dst = pathlib.Path(sys.argv[2])
text = src.read_text(encoding="utf-8")
old = r"\usepackage{gnuplot-lua-tikz}"
new = (
    "% gnuplot-lua-tikz often unavailable; tikz covers embedded tikzpicture figures\n"
    r"\usepackage{tikz}"
)
if old in text:
    text = text.replace(old, new, 1)
elif r"\usepackage{tikz}" not in text:
    needle = r"\usepackage[utf8]{inputenc}"
    if needle in text:
        text = text.replace(
            needle,
            needle + "\n" + new,
            1,
        )
dst.write_text(text, encoding="utf-8")
PY

# --- 5. pdflatex / bibtex ---
run_pdflatex() {
  local pass="$1"
  log "pdflatex (pass ${pass})"
  if ! pdflatex -interaction=nonstopmode book.tex >/dev/null; then
    echo "error: pdflatex failed (pass ${pass}); last lines of book.log:" >&2
    if [[ -f book.log ]]; then
      tail -n 80 book.log >&2
    fi
    return 1
  fi
}

(
  cd "$PDF_DIR"
  run_pdflatex 1
  bibtex book >/dev/null || true
  run_pdflatex 2
  run_pdflatex 3
)

cp -f "$PDF_DIR/book.pdf" "$ROOT/i18n/book-es.pdf"
log "wrote i18n/book-es.pdf"
ls -la "$ROOT/i18n/book-es.pdf"
