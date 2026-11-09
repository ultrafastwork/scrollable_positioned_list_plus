# 4. Long-scroll direction uses a stale target — verify before fixing

**Area:** correctness · **Line numbers:** `598e545`

**Status:** done in agent/list-state — reproduced (anchor 50, drag to 200, `scrollTo(100)` moved the visible list to 204); direction now comes from the lowest visible index, falling back to `primary.target`.

- **File:** `lib/src/scrollable_positioned_list.dart`, `_startScroll`: `final direction = index > primary.target ? 1 : -1;`
- **Suspected problem:** `primary.target` is the item the list was last anchored to, not what's on screen. Say the user `jumpTo(50)`, then drags manually to item 200, then calls `scrollTo(100)`. The direction is computed as forward, so the transition animates the wrong way. It still ends at the right place.
- **Fix direction:** derive the direction from the current visible positions, for example the lowest visible `index` in `primary.itemPositionsNotifier.itemPositions.value`. Fall back to `primary.target` if that's empty.
- **Acceptance:** first write a test showing that intermediate positions move away from the target. If you can't reproduce it, drop the task and report back.
