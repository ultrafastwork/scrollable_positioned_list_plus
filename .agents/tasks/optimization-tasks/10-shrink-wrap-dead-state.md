# 10. Remove dead state in the shrink-wrap viewport

**Area:** performance (cleanup) · **Line numbers:** `598e545`

**Status:** done in agent/list-state-followups — removed `lastMainAxisExtent` and `growSize` (no references in `lib/`, `test/` or `example/`; `wrapping.dart` isn't exported).

- **File:** `lib/src/wrapping.dart`: `lastMainAxisExtent` (line 136) is never read. `growSize` (line 809, written at line 342) is written but never read anywhere in `lib/`.
- **Fix:** delete both. A pure cleanup; also check `test/` and `example/` for references first.
