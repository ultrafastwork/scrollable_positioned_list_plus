# 21. Reduce the cost of the long-scroll crossfade (low priority)

**Area:** performance · **Line numbers:** `a0ee16b`

**Status:** done. Two changes with no visible effect are merged: the secondary list mounts at the offset where its animation starts, and `PositionedList` widgets are reused so already-built items aren't rebuilt. Over 10 long `scrollTo` calls, dropped vsyncs fall from about 130 to about 86, build p99 from about 71 to about 62 ms, and the worst frame from about 82 to about 70 ms. The smaller secondary cache (idea 1) was measured and rejected. Idea 2 already holds in the framework. Idea 3 changes the visible animation and was already measured as not worth it in [task 20](20-fixed-extent-mode.md), so it wasn't pursued.

- **Files:** `lib/src/scrollable_positioned_list.dart`, `build` (lines 465-492), `_buildList` (lines 494-527), `_startScroll` transition branch (lines 635-689).
- **Problem:** during a long-distance `scrollTo`, two full `PositionedList`s are built and laid out, each with the large cache extent. Both are scrolling every frame and both sit under a `FadeTransition`, which means two opacity layers to composite. That costs extra in both build time and GPU (raster) time. The secondary list's items are also built from scratch, which shows up as a build spike in the frame where it mounts.
- **Ideas (measure each one; drop any that don't help):**
  - **Smaller cache for the secondary list while it's transitioning.** It only needs about one viewport of items to look right. The catch: it becomes the primary after the swap, so restoring the cache extent then triggers builds in the swap frame. Measure whether that's a net win.
  - **Check that the fully faded-out list is skipped at paint.** `RenderAnimatedOpacity` skips painting at alpha 0. Confirm the primary isn't painted after the fade completes and before `_stopScroll` removes the secondary.
  - **"Jump near, then animate."** As an alternative to the crossfade, `jumpTo` about one screen before the target and `animateTo` the rest on a single list, so there's never a second list. **This changes the visible animation, so it needs owner approval.** It could be offered as an option on `scrollTo`.
- **Acceptance:** build and raster p90/p99 for the "long `scrollTo`" scenario from task 22, before and after, recorded here. No regression in the existing transition tests (including tasks 2, 11, 12, 15 and 16).

## Where the time went

The per-frame build times in the baseline JSON show the same pattern for every long `scrollTo`:

1. **About 72 ms: the mount frame.** `_startScroll` calls `setState`, which mounts the secondary list. The secondary builds its viewport plus 2 screens of cache on each side, about 5 screens of items. The same `setState` also rebuilds the whole primary list: `PositionedList.build` creates new `SliverChildBuilderDelegate`s, so every built primary item (about 5 screens of them) runs `itemBuilder` again.
2. **About 20–30 ms: the frame after.** The start callback runs after the mount frame and `jumpTo`s the secondary 2 screens back from where it was mounted. This frame lays out about 2 more screens of new secondary items.
3. **A few 10–13 ms frames** while both lists scroll and build items at their edges.
4. **The swap frame.** `_stopScroll` calls `setState` again, which rebuilds all the items of the new primary (the old secondary) once more.

## What changed

- **Mount the secondary at its start offset** (removes frame 2). `_ListDisplayDetails.scrollController` is now a private `_ListScrollController`, whose `initialScrollOffset` returns a settable `nextInitialOffset`. `_startScroll` sets it to the offset the animation starts from, just before the `setState` that mounts the secondary. The start callback resets it to 0 and still calls `jumpTo` with the same expression as before. That call is normally a no-op, but it keeps the old behaviour if the secondary was ever mounted some other way. Nothing changes on screen, because the secondary is at opacity 0 until its animation starts.
- **Reuse the `PositionedList` widget** (cuts the primary rebuild in frame 1 and the rebuild in frame 4). `_buildList` gets its `PositionedList` from `_positionedList`, which returns the instance cached on `_ListDisplayDetails.list` while `target`, `alignment` and the cache extent are unchanged. An identical widget instance makes the framework skip the subtree. `didUpdateWidget` clears both caches, so a new `itemBuilder`, `itemCount`, `padding` and so on still take effect straight away.
  - **Side effect:** `itemBuilder` is called less often. Items already built are no longer rebuilt when the crossfade starts or ends. They're also no longer rebuilt when the list's constraints change without changing the cache extent, for example a width change on a vertical list. They are still laid out again. This matches what a `ListView` does in the same situations, and an item that depends on an `InheritedWidget` (`MediaQuery`, `Theme`, and so on) still rebuilds through that dependency. It's mentioned in the changelog.
- **Tests:** `A long scrollTo does not rebuild items already built` fails on the old `lib/` (2 builds instead of 1) and passes now. `A new itemBuilder is used after a long scrollTo` guards the cache invalidation in `didUpdateWidget`; it fails if the two lines that clear the caches are removed. `flutter test`: 208 passed (206 + the 2 new ones). `flutter analyze`: no issues. The example's tests pass.

## Ideas that weren't merged

- **Smaller secondary cache (idea 1): measured, rejected.** The throwaway patch gave the secondary a cache of 1 viewport (instead of 2) while transitioning, on top of both changes above. It splits the mount spike in two: about 40 ms at the mount, then about 30 ms in the swap frame, where the cache is restored and the new primary rebuilds with it. Build p99 drops to about 42–51 ms, but more frames go over budget (24–36 against 22–24), more vsyncs are dropped (93–124 against 84–88), and total build time is higher. Users would see two hitches per scroll instead of one. It would also change behaviour: right after the swap, the new primary's positions cover only the smaller cache, so a `scrollTo` issued as soon as the previous one completes could crossfade where it used to animate directly.
- **Faded-out list skipped at paint (idea 2): already the case, no change needed.** `RenderAnimatedOpacityMixin.paint` returns straight away when `_alpha == 0`, and `isRepaintBoundary` is false at alpha 0, so no opacity layer is pushed either. Read in the Flutter 3.47.7 source, `rendering/proxy_box.dart`. With the default weights `[40, 20, 40]`, the secondary is invisible for the first 40 % and the primary for the last 40 %, so two opacity layers are composited only during the middle 20 %. Raster time was flat in every measurement (p90 about 4–5 ms), which agrees.
- **"Jump near, then animate" (idea 3): not pursued.** It changes the visible animation and needs owner approval. [Task 20](20-fixed-extent-mode.md) has already measured the equivalent "jump to 2 screens out, then animate": the jump frame costs as much as the crossfade's mount frame (p99 63–67 ms), and the jump is a visible teleport. Its recommendation is not to do it.

## Measurements

- **Device:** Redmi Note 15 (`2510DRA23E`), Android 16, 120 Hz, the same device as the [task 22 baseline](22-device-profiling-harness.md#baseline)
- **Flutter:** 3.47.7 stable, profile mode, Impeller
- **Package commit:** before is `475b8a1`. After is that commit plus this task's change.
- **Runs:** two per variant, same build. Cells show run 1 / run 2. Times are in ms.
- **"Dropped vsyncs"** is computed from the per-frame build times in the JSON, as the sum of `ceil(build / 8.33) − 1` over all frames. It's the 120 Hz equivalent of the harness's "missed build" count, which assumes a 16 ms budget.

### `long_scroll_to`

| variant | frames | build avg | build p90 | build p99 | build worst | missed build (16 ms) | frames > 8.33 ms | dropped vsyncs | raster p90 | raster p99 |
|---|---|---|---|---|---|---|---|---|---|---|
| before | 637 / 608 | 4.03 / 4.14 | 5.00 / 5.87 | 72.50 / 69.34 | 90.79 / 73.85 | 21 / 23 | 43 / 44 | 132 / 125 | 4.59 / 5.34 | 8.98 / 11.25 |
| start offset only | 659 / 654 | 3.69 / 3.67 | 4.99 / 5.22 | 72.21 / 67.13 | 80.28 / 85.61 | 13 / 12 | 27 / 29 | 101 / 102 | 4.68 / 4.72 | 8.68 / 9.09 |
| **after (start offset + reuse)** | 677 / 686 | 3.31 / 3.33 | 4.73 / 4.65 | 60.26 / 62.15 | 64.56 / 69.31 | 13 / 13 | 23 / 24 | 84 / 88 | 4.66 / 4.70 | 7.58 / 8.70 |
| after + smaller secondary cache (rejected) | 726 / 725 | 3.34 / 3.25 | 3.90 / 3.79 | 42.64 / 42.35 | 58.70 / 51.23 | 20 / 21 | 31 / 36 | 96 / 99 | 4.43 / 4.59 | 8.00 / 9.11 |

### `long_scroll_to_separated`

| variant | frames | build avg | build p90 | build p99 | build worst | missed build (16 ms) | frames > 8.33 ms | dropped vsyncs | raster p90 | raster p99 |
|---|---|---|---|---|---|---|---|---|---|---|
| before | 631 / 608 | 4.38 / 4.44 | 5.10 / 5.40 | 74.47 / 68.15 | 86.33 / 83.34 | 23 / 24 | 43 / 42 | 141 / 137 | 3.87 / 4.18 | 8.28 / 10.61 |
| start offset only | 644 / 663 | 3.94 / 3.98 | 4.85 / 4.74 | 71.87 / 65.39 | 85.89 / 94.36 | 13 / 17 | 31 / 35 | 110 / 114 | 4.23 / 4.18 | 9.34 / 10.92 |
| **after (start offset + reuse)** | 701 / 694 | 3.39 / 3.45 | 4.32 / 4.35 | 63.20 / 63.81 | 67.02 / 77.46 | 13 / 12 | 23 / 22 | 86 / 88 | 4.20 / 3.89 | 9.03 / 8.66 |
| after + smaller secondary cache (rejected) | 645 / 648 | 4.09 / 3.71 | 5.25 / 4.85 | 51.42 / 49.03 | 130.79 / 57.56 | 21 / 20 | 33 / 24 | 124 / 93 | 4.86 / 4.38 | 13.06 / 9.30 |

The other scenarios (drag ×3, `short_scroll_to`) don't use the crossfade and stayed within run-to-run noise in every variant. For example, `drag_with_listener` build avg was 1.32 / 1.17 before and 1.18 / 1.17 after, and `short_scroll_to` was 1.28 / 1.25 before and 1.26 / 1.26 after.

### What the numbers show

- **About a third fewer dropped vsyncs.** Over 10 long scrolls the count goes from 125–141 to 84–88, both runs agree, and it holds for `.separated` too. Frames over the 8.33 ms budget fall from about 43 to about 23, and about 10 % more frames are delivered in the same time.
- **The mount spike is smaller, but it's still there.** Build p99 goes from 68–74 to 60–64 ms and the worst frame from 74–91 to 65–77 ms, because the primary's items are no longer rebuilt in that frame. The remaining 60 ms is the secondary building about 5 screens of items from scratch. Only a smaller cache extent overall ([task 18](18-default-cache-extent.md), which measured this frame halving) or fewer crossfades ([task 20](20-fixed-extent-mode.md)) shrinks it further.
- **Raster time is unchanged**, as idea 2 predicted.
