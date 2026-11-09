# 13. Position comparison is order-sensitive (low priority)

**Area:** performance · **Line numbers:** `e72c4d4`

**Status:** done in agent/list-state-followups — reproduced (drag away and back so items re-register out of order, then `jumpTo` the item already at the top: same positions, reversed order, listener fired once); both comparisons now use `samePositions` (`listEquals` fast path, then length + `setEquals`). Assigned lists are never sorted; when an update is skipped, listeners keep the previous value and its order. **Superseded by `22d1e85`:** positions are now sorted by index when collected (owner-approved, in the changelog), and `samePositions` is a plain `listEquals`.

- **Files:** `lib/src/positioned_list.dart` (~line 385) and `lib/src/scrollable_positioned_list.dart` `_updatePositions` (~line 764)
- **Problem:** task 8 compares positions with `listEquals`, but they're collected by iterating a `Set<Element>` registry. If the same positions come back in a different order (for example after elements re-register), listeners are notified anyway. Harmless, just not fully deduplicated.
- **Fix direction:** only if it stays cheap, for example sort by `index` before comparing, or compare as sets. Don't change the order users see unless the owner approves.
