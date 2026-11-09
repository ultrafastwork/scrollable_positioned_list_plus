# 21. Reduce the cost of the long-scroll crossfade (low priority)

**Area:** performance · **Line numbers:** `a0ee16b`

**Status:** not started. Do this after [task 18](18-default-cache-extent.md) and [task 20](20-fixed-extent-mode.md), which make transitions rarer, and only if [task 22](22-device-profiling-harness.md) still shows janky transitions.

- **Files:** `lib/src/scrollable_positioned_list.dart`, `build` (lines 465-492), `_buildList` (lines 494-527), `_startScroll` transition branch (lines 635-689).
- **Problem:** during a long-distance `scrollTo`, two full `PositionedList`s are built and laid out, each with the large cache extent. Both are scrolling every frame and both sit under a `FadeTransition`, which means two opacity layers to composite. That costs extra in both build time and GPU (raster) time. The secondary list's items are also built from scratch, which shows up as a build spike in the frame where it mounts.
- **Ideas (measure each one; drop any that don't help):**
  - **Smaller cache for the secondary list while it's transitioning.** It only needs about one viewport of items to look right. The catch: it becomes the primary after the swap, so restoring the cache extent then triggers builds in the swap frame. Measure whether that's a net win.
  - **Check that the fully faded-out list is skipped at paint.** `RenderAnimatedOpacity` skips painting at alpha 0. Confirm the primary isn't painted after the fade completes and before `_stopScroll` removes the secondary.
  - **"Jump near, then animate."** As an alternative to the crossfade, `jumpTo` about one screen before the target and `animateTo` the rest on a single list, so there's never a second list. **This changes the visible animation, so it needs owner approval.** It could be offered as an option on `scrollTo`.
- **Acceptance:** build and raster p90/p99 for the "long `scrollTo`" scenario from task 22, before and after, recorded here. No regression in the existing transition tests (including tasks 2, 11, 12, 15 and 16).
