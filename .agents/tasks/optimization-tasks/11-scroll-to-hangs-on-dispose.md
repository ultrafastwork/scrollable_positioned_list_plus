# 11. `scrollTo` future hangs if the list is disposed before the transition starts

**Area:** correctness · **Line numbers:** `e72c4d4`

**Status:** done in agent/list-state-followups — `dispose` now calls `_cancelPendingStart()`, so a long scroll's pending futures complete when the list is removed before the secondary list mounts.

- **File:** `lib/src/scrollable_positioned_list.dart`, `dispose` (~line 409)
- **Problem:** task 2 completes a long scroll's pending futures in `_stopScroll`, but `dispose` doesn't. If the list is removed after `scrollTo(index: far)` and before the secondary list mounts, `await scrollTo(...)` never completes.
- **Fix direction:** call `_cancelPendingStart()` in `dispose`.
- **Acceptance:** a test that calls `scrollTo(index: far)`, then replaces the list with an empty widget before pumping. The returned future must complete.
