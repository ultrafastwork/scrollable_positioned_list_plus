# 23. A newly passed `itemPositionsListener` stays empty until something moves

**Area:** correctness · **Line numbers:** `757f284`

**Status:** not started.

- **Files:** `lib/src/scrollable_positioned_list.dart` (`didUpdateWidget` lines 435-462, `_updatePositions` lines 764-787).
- **Problem:** if a rebuild passes an `itemPositionsListener` to a list that already exists, `itemPositions.value` stays `[]` until the list scrolls or its positions change for another reason. That covers adding a listener where there was none, and swapping one listener for another. `_updatePositions` only runs when the internal per-list notifier fires. That notifier only fires when the computed positions differ from the last ones (task 8), and they don't, because nothing moved.
- **Repro:** pump a list with no listener and `jumpTo(index: 30)`. Rebuild it with `ItemPositionsListener.create()` and pump one frame. `value` is still empty, but it should start with index 30. Rebuilding again with a second fresh listener gives the same result. The test "a listener passed later gets positions straight away" in [`19-part-a-not-merged.patch`](19-part-a-not-merged.patch) (`test/list_state_regression_test.dart`) does this, and it fails on `1d00abb`.
- **Fix direction:** in `didUpdateWidget`, when `widget.itemPositionsNotifier` is non-null and not identical to `oldWidget.itemPositionsNotifier`, add a post-frame callback that calls `_updatePositions()` (guarded by `mounted`). The internal notifier already holds the current primary positions, because on `main` they are computed after every frame whether or not a listener is passed. So no recomputation is needed. (The task 19 patch also recomputes them, but only because it stopped tracking positions without a listener.)
- **Watch out:** don't assign the user notifier during `didUpdateWidget` itself. That would call the app's listeners during build, and a listener that calls `setState` would throw. Keep the task-8 rule of not notifying when nothing changed: `_updatePositions` already compares with `samePositions`.
- **Acceptance:** a regression test that fails before the fix and passes with it, covering both cases (no listener → listener, and listener A → listener B). All existing tests pass and `flutter analyze` is clean. Add a "Fix:" line to the changelog.
