# 19. Compute item positions only when needed, and more cheaply

**Area:** performance · **Line numbers:** `a0ee16b`

**Status:** not started. **Do part A first. Do part B only if profiling shows it matters.** Commit each part separately.

- **Files:** `lib/src/positioned_list.dart` (`_schedulePositionNotificationUpdate`, lines 316-393), `lib/src/scrollable_positioned_list.dart` (`_ListDisplayDetails` line 793, `_startScroll` lines 610-622, `_updatePositions` lines 764-787), `lib/src/item_positions_notifier.dart`.
- **Problem:** after every frame in which the scroll controller moves (and after every `didUpdateWidget`), `PositionedList` walks every registered item, cached ones included (see [task 18](18-default-cache-extent.md)). For each item it calls `getOffsetToReveal` (vertical) or `localToGlobal` (horizontal), both of which walk up the render tree, and allocates an `ItemPosition`. It then sorts and compares the whole list. Each `_ListDisplayDetails` always creates an internal `ItemPositionsNotifier`, so this runs even when the app passes no `itemPositionsListener`.

## Part A: skip the work when nobody needs it

The internal positions have three consumers:
1. the user's `itemPositionsListener`, through `_updatePositions`
2. `PageStorage`, which `_updatePositions` writes every frame (line 775) so the scroll position is restored on re-creation
3. `_startScroll`, which reads them once per call to pick the direction and decide between a direct animation and a crossfade

- **Fix direction:**
  - Only schedule the per-frame computation when a user listener is attached. `ChangeNotifier.hasListeners` is `@protected`, so expose it through `ItemPositionsNotifier` or a small subclass.
  - For `_startScroll`, compute positions on demand, synchronously, from the last laid-out render objects. That's the same data the post-frame callback reads today, so behaviour matches.
  - For `PageStorage`, write once in `deactivate` (the context is still valid there; it isn't in `dispose`) instead of every frame. Check that restore still works with a `PageStorageKey` in a `TabBarView`/`PageView`. That's the case the existing write supports.
- **Watch out:** a listener added later must get correct positions straight away, so trigger one computation when the first listener attaches. The task-8 behaviour (no notification when nothing changed) and the post-swap `_updatePositions()` call in `_stopScroll` must keep working.
- **Acceptance:** with no `itemPositionsListener`, a drag frame does no position work (count calls in a test, or assert that the post-frame callback isn't scheduled). All position, `PageStorage` and `scrollTo` tests pass. Benchmark numbers for "drag, no listener" before/after recorded here.

## Part B: compute positions with arithmetic instead of tree walks

- **Fix direction:** read each child's `layoutOffset` from `SliverMultiBoxAdaptorParentData` and combine it with its sliver's `constraints.scrollOffset`/`precedingScrollExtent` and the viewport's anchor and offset. That's simple arithmetic per item instead of a tree walk. Walking each sliver's children in order also yields positions sorted by index, so `positions.sort(...)` can go.
- **Hard parts:**
  - The leading sliver (before the center) grows in the reverse direction.
  - `reverse: true`, horizontal axis, `padding`, separators (odd child indices) and the shrink-wrapping viewport all change the math.
  - The `.round()` on pixel offsets must be kept so reported values stay identical.
- **Gate:** only do this if a profile from [task 22](22-device-profiling-harness.md) shows position computation is a significant share of frame time after part A, for apps that do listen. Otherwise close part B as "not worth it" with the numbers.
- **Acceptance:** reported positions are byte-identical to the old computation across the existing vertical/horizontal/reversed/separated/shrink-wrap tests. Consider a temporary debug assert comparing both computations while developing.
