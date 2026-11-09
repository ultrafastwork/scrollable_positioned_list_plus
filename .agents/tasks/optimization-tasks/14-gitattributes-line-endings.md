# 14. Add `.gitattributes` for line endings

**Area:** tooling · **Line numbers:** `e72c4d4`

**Status:** done in agent/list-state-followups — added `* text=auto eol=lf` plus `binary` for image/font/jar types; `git add --renormalize .` staged nothing else (the index was already all LF; the only binaries, 5 launcher PNGs, are untouched).

- **File:** new `.gitattributes` at the repo root
- **Problem:** with no `.gitattributes`, commits on Windows warn "LF will be replaced by CRLF", and line endings depend on each contributor's `core.autocrlf`.
- **Fix:** add `* text=auto eol=lf` (plus `binary` entries for any binary assets), then run `git add --renormalize .` and check that the diff is empty or endings-only. Commit as `chore:`.
