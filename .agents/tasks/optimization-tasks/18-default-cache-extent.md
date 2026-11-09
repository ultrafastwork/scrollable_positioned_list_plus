# 18. Shrink the default cache extent — NEEDS OWNER DECISION

**Area:** performance · **Line numbers:** `a0ee16b`

**Status:** not started.

- **Files:** `lib/src/scrollable_positioned_list.dart`: `_screenScrollCount` (line 19), `minCacheExtent` (lines 175-182), `_cacheExtent` (lines 529-535), the direct-vs-transition check in `_startScroll` (lines 620-634).
- **Problem:** `_cacheExtent` is `max(viewportExtent × 2, minCacheExtent ?? 0)` on **each side** of the viewport. Flutter's default is 250 px. On an 800 px viewport, that's about 3,200 px of off-screen items built, laid out, registered and position-tracked on every frame, versus about 500 px for a `ListView`. Users can raise it through `minCacheExtent`, but they can't lower it. This is probably the largest steady-state cost in the package. It also multiplies the per-item cost in [task 19](19-lazy-position-computation.md).
- **Why it's this big:** `_startScroll` animates directly only when the target already has an `ItemPosition`, meaning it was built inside the cache extent. Otherwise it crossfades. The large cache makes "nearby" cover about two screens in each direction. Shrinking it means medium-distance `scrollTo` calls switch from a direct animation to a crossfade. **That is a visible behaviour change, so it needs owner approval.**
- **Options (pick with the owner):**
  1. **Opt-in large cache.** Default to the framework cache extent and keep today's behaviour behind a flag, or turn `minCacheExtent` into a full `cacheExtent` override.
  2. **Estimate nearby targets.** Use the normal cache extent. For a target outside the built items but within about two screens, estimate its offset from the average extent of the built items, `animateTo` that, then correct for the remaining error at the end, or re-target mid-animation when the item gets built. This keeps direct animation for medium distances. The risk is a small visible correction with variable-height items.
  3. **Don't raise the cache temporarily when `scrollTo` starts.** It looks attractive, but it builds about two screens of items in one frame, right at the start of the animation, which is the worst time for jank. Listed here so nobody picks it up without measuring.
- **Measure first:** using [task 22](22-device-profiling-harness.md), or the benchmark if no device is available, record the number of built items and the build/layout time per frame with today's cache extent versus 250 px. If the difference is small, close the task as "not worth it" and record the numbers here.
- **Acceptance:** before/after numbers recorded in this file. Tests that assert a direct animation for targets 1–2 screens away are updated only as far as the approved option requires. Changelog entry for the behaviour change.
