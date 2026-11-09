# 19. Compute item positions only when needed, and more cheaply

**Area:** performance · **Line numbers:** `a0ee16b`

**Status:** closed, not worth it (2026-11-09). Part A was implemented and tested, but the device harness showed no measurable gain, so it wasn't merged. The diff is kept in [`19-part-a-not-merged.patch`](19-part-a-not-merged.patch). Part B is closed by its gate. See [Outcome](#outcome).

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

## Outcome

### What part A did (not merged)

The patch applies cleanly on `1d00abb`. With it, `flutter test` gives 211 passed (204 plus 7 new tests) and `flutter analyze` reports no issues.

- **Gate:** per-frame position work runs only when the app passes an `itemPositionsListener`. `PositionedList` takes a null notifier and skips its post-frame callback entirely.
- **Not gated on `hasListeners`, as the fix direction suggested.** Many tests, and probably apps, read `itemPositionsListener.itemPositions.value` without ever adding a listener (for example the `PageView` restore tests). Gating on `hasListeners` would leave `.value` stale for them, which is an observable behaviour change. Gating on whether a listener object was passed changes nothing anyone can observe.
- **`_startScroll`** computes positions on demand through a new internal `PositionedListHandle`, from the same render objects the post-frame callback reads.
- **`PageStorage` can't be written in `deactivate`.** The fix direction is wrong here. By the time `State.deactivate` runs, Flutter has already cleared `Element._parent` (so `PageStorage.maybeOf` finds nothing) and detached the render subtree, so `getTransformTo` asserts `attached`. Instead, the patch saves in a post-frame callback after every build of the list and when a scroll of the primary list ends, as Flutter's own `ScrollPosition.saveScrollOffset` does. That covers `jumpTo`, the crossfade swap, resizes and widget updates.
- **Found and fixed on the way: a stale new listener.** An `itemPositionsListener` passed to an existing list, or swapped for another, stayed empty until something moved. This bug also exists on `main` today. The patch's test "a listener passed later gets positions straight away" fails on `1d00abb`. It is worth a small correctness task of its own (one post-frame refresh in `didUpdateWidget` when the notifier changes), independent of this one.

### Numbers

**Device harness**, Redmi Note 15 (`2510DRA23E`, Android 16), profile mode, build times in ms:

| scenario | before run 1 | before run 2 | after run 1 | after run 2 |
|---|---|---|---|---|
| drag_without_listener, build avg | 1.34 | 1.27 | 1.31 | 1.43 |
| drag_without_listener, build p90 | 3.03 | 2.81 | 2.92 | 3.26 |
| drag_with_listener, build avg (control, unchanged path) | 1.25 | 1.24 | 1.24 | 1.28 |
| short_scroll_to, build avg (control) | 1.30 | 1.26 | 1.28 | 1.39 |

The second "after" run was slower on every scenario, including the control paths the patch doesn't change, so it shows device drift rather than a regression. Across both runs the difference sits inside the 5–10 % run-to-run noise. A third "after" run failed without printing results; it was rerun.

**Host benchmark** (`flutter test benchmark/scroll_benchmark_test.dart`, µs/frame, "drag scroll, no listener" scenario added in this commit), interleaved old/new on the same machine:

| pair | builder old → new | separated old → new |
|---|---|---|
| 1 | 3004 → 2510 | 2819 → 2786 |
| 2 | 2411 → 2009 | 2418 → 2049 |
| 3 | 2123 → 3704 | 2859 → 4389 |

Pair 3 drifted 30–60 % on every scenario, including unchanged ones. The host machine is too noisy to show a gain this small.

### Why part B is closed

Part A removes *all* position work from a drag frame when there is no listener, and that saving is below what the device can measure (≈ 0.1 ms or less out of ≈ 1.3 ms build time). Part B could only make the same work cheaper for apps that do listen, so its gain is smaller still. That fails its gate ("a significant share of frame time").

### If this is picked up again

The work only shows on lists that build many more items per frame (for example, if [task 18](18-default-cache-extent.md) is rejected and a phone renders very small items), or on much slower devices. Measure there first, then `git apply 19-part-a-not-merged.patch`.
