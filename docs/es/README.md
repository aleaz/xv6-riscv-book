# Spanish edition (ES)

Spanish localization of the [xv6 RISC-V book](https://github.com/mit-pdos/xv6-riscv-book)
on branch `es` of this fork ([aleaz/xv6-riscv-book](https://github.com/aleaz/xv6-riscv-book)).

The English `.tex` sources stay untouched. Translations live in LILT Translation
Memory under `.lilt/tm/` (JSONL). Rebuilt Spanish `.tex` and the PDF are
**generated** (`scripts/build-es.sh`); they are not edited by hand in the source tree.

## Copyright and attribution

The book sources are:

> Copyright (c) 2006–2024 Russ Cox, Frans Kaashoek, and Robert Morris,
> Massachusetts Institute of Technology

See the repository `LICENSE`. This Spanish edition is an unofficial translation
overlay maintained with [LILT](https://github.com/aleaz/lilt); it does not alter
the MIT copyright of the original text.

## Status

Machine baseline (check before every push):

```bash
lilt tm status --all
# expect: 0 generated, 0 conflict, 0 error
./scripts/build-es.sh   # must exit 0 → i18n/book-es.pdf
```

Human review (`reviewed` / `approved` / `locked`) is optional and separate.

Maintenance when English changes: [UPSTREAM.md](UPSTREAM.md)
(includes pre-push checklist, remask runbook, prune).

## Requirements

- TeX Live (or equivalent) with `pdflatex` and `bibtex`
- [uv](https://github.com/astral-sh/uv) and [LILT](https://github.com/aleaz/lilt) (Python 3.13+)
- Network once to clone `mit-pdos/xv6-riscv` for `lineref` line numbers (same as English `make`)
- Local OpenAI-compatible LLM only when **translating** (not needed for PDF build from committed TM)

## Layout

| Path | Role |
|------|------|
| `.lilt/lilt.yaml` | LILT project config (EN→ES, glossary, macros) |
| `.lilt/tm/*.jsonl` | Translation Memory (versioned) |
| `scripts/es-sources.txt` | SSOT list of `.tex` files for sync + build |
| `scripts/sync-es.sh` | Sync all listed sources into TM |
| `scripts/build-es.sh` | Build Spanish PDF from TM |
| `docs/es/UPSTREAM.md` | Merge / sync / gate / release procedure |
| `i18n/build/`, `i18n/pdf/` | Regenerable outputs (not committed) |

## Everyday commands

From the repository root on branch `es`:

```bash
# TM overview
lilt tm status --all

# Sync all sources listed in scripts/es-sources.txt
./scripts/sync-es.sh

# Translate pending segments in one namespace (no --force unless intentional)
lilt pipeline translate lock

# Rebuild Spanish PDF (uses TM; no LLM)
./scripts/build-es.sh
# → i18n/book-es.pdf
```

If `lilt` is not on `PATH`, point at a LILT checkout (scripts pass `--work-dir` for you):

```bash
export LILT_CMD='uv run --directory /path/to/lilt lilt'
./scripts/sync-es.sh
./scripts/build-es.sh
```

## When the English book changes

Follow [UPSTREAM.md](UPSTREAM.md): merge `xv6-riscv` → `es`, update
`es-sources.txt` if needed, `./scripts/sync-es.sh`, translate pendings, pass
the quality gate, commit TM.

`origin/es` already tracks the English tip; localization commits fast-forward
on top — no force-push required for the normal workflow.
