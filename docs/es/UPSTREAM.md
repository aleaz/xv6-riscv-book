# Updating the Spanish edition when English changes

Branch model:

- `xv6-riscv` — tracks the English book (merge from MIT upstream).
- `es` — localization overlay: same English `.tex` + `.lilt/` + docs/scripts.

Spanish text is **not** stored by rewriting the English sources. After a merge,
re-sync into TM, translate new/`generated`/`conflict` segments, then rebuild.

Source list SSOT: [`scripts/es-sources.txt`](../../scripts/es-sources.txt)
(sync + build both read it). If `book.tex` gains or loses
`\input{latex.out/...}`, update that file in the **same** change.

## Canonical sequence

### 1. Refresh English tracking branch

```bash
git checkout xv6-riscv
git remote add upstream https://github.com/mit-pdos/xv6-riscv-book.git   # once
git fetch upstream
git merge upstream/xv6-riscv    # MIT publishes xv6-riscv (not master)
# resolve conflicts in English sources if any
git push origin xv6-riscv       # when ready
```

### 2. Bring English into `es`

```bash
git checkout es
git merge xv6-riscv
```

Resolve conflicts only in files you edited by hand on `es` (docs, scripts,
`.lilt/lilt.yaml`). Prefer not to hand-merge JSONL; if both sides touched the
same TM file, re-sync that namespace from the merged `.tex` instead.

### 3. Keep the source list in sync with `book.tex`

If upstream added/removed/renamed a chapter:

1. Edit [`scripts/es-sources.txt`](../../scripts/es-sources.txt).
2. Include new `fig/*.tex` paths so `sync-es.sh` tracks them (PDF still uses
   English `fig/` via symlink until that staging is changed on purpose).

### 4. Sync all Spanish sources

```bash
export LILT_CMD='uv run --directory /path/to/lilt lilt'   # if needed
./scripts/sync-es.sh
```

### 5. Inspect TM

```bash
lilt tm status --all   # or: $LILT_CMD --work-dir . tm status --all
```

Count `generated` (new or remasked), `conflict` (human-protected + source
change, or validation), `error` (API/infra), and `deprecated` (orphans).

### 6. Translate pendings

Translate **without** `--force` for namespaces that still have work:

```bash
lilt pipeline translate <namespace>
# single segment: lilt pipeline translate <ns> --id <prefix> --force --stage draft
# then critique + refine stages as needed
```

Use `--force` only for intentional glossary/parser rewrites, never as a default
mass re-translate — especially not over `reviewed` / `approved` / `locked`.

### 7. Quality gate (required before commit)

Do **not** commit or push until all of the following hold:

1. `generated` = `conflict` = `error` = **0** (WIP stays local).
2. `./scripts/build-es.sh` exits **0** (writes `i18n/book-es.pdf`).
3. Spot-check (macros/Unicode junk from the LLM):

```bash
rg '\\indextext[A-Za-záéíóúñÁÉÍÓÚÑ]|و' i18n/build/*.tex \
  && echo 'FAIL: broken macros or bad unicode' || echo 'OK'
```

`refined` ≠ TeX-safe. If the gate fails, fix with `--id` re-translate or
`pipeline edit`, then rebuild.

`lineref` “cannot find pat” messages are OS↔book drift; they do **not** mean
the translation failed.

### 8. Commit localization state

Commit `.lilt/tm/` (and `.lilt/lilt.yaml` / `scripts/es-sources.txt` if changed).
Do **not** commit `.lilt/.env`, `*.db`, `lilt.log`, or anything under `i18n/`.

```text
i18n: sync upstream YYYY-MM-DD
```

### 9. Optional release tag

Tag `es-YYYY.MM.DD` to trigger CI release of `book-es.pdf` (see
`.github/workflows/build-es-pdf.yml`).

## Pre-push checklist

- [ ] `scripts/es-sources.txt` matches `book.tex` chapter list
- [ ] `./scripts/sync-es.sh` already run after the merge (or config change)
- [ ] `tm status --all` → 0 `generated` / `conflict` / `error`
- [ ] `./scripts/build-es.sh` exit 0
- [ ] Spot-check `rg` above clean
- [ ] No `.env` / dbs / PDF in the commit

## Config-only remask (no English merge)

After editing `.lilt/lilt.yaml` (parser / glossary / transparent macros):

```bash
./scripts/sync-es.sh
# translate only namespaces with generated…
./scripts/build-es.sh   # must exit 0
```

Same quality gate as step 7.

## Removed chapters

After sync, orphans become `deprecated`. Clean up when ready:

```bash
lilt tm admin prune <namespace>
```

## Failure table

| Symptom | What to do |
|---------|------------|
| Segment `conflict` | Human queue: `pipeline edit` / `pipeline review`; do not blind `--force` on human-protected statuses |
| Segment `error` | Infra/API: retry `pipeline translate`; check LLM endpoint |
| Many `generated` after parser/mask change | Expected; translate those namespaces without mass `--force` on `refined`/`approved` |
| Merge conflict in `*.jsonl` | Prefer re-`sync` + re-translate pendings over manual JSONL merge |
| `build-es.sh` / CI fails on build | TM not buildable or TeX error; read dumped `book.log` tail; fix segments |
| Tempted to `--force` everything | Only for glossary/parser campaigns; document why in the commit |
| CI breaks after LILT upgrade | Pin in `.github/workflows/build-es-pdf.yml`; bump only after local `build-es.sh` OK with that ref |
| `lineref` cannot find pat | Noise; not a translation failure |

## Bumping the CI LILT pin

Workflow checks out `aleaz/lilt` at a fixed tag/SHA. To bump:

1. Validate locally with that LILT revision: `LILT_CMD=... ./scripts/build-es.sh`
2. Change `ref:` in `.github/workflows/build-es-pdf.yml`
3. Commit with note of the new pin
