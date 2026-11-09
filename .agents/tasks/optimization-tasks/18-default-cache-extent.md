# 18. Shrink the default cache extent — NEEDS OWNER DECISION

**Area:** performance · **Line numbers:** `a0ee16b`

**Status:** blocked on owner decision. Measurements are done (below) and show a clear gain. No code has changed. Pick an option under [Recommendation](#recommendation) to unblock.

- **Files:** `lib/src/scrollable_positioned_list.dart`: `_screenScrollCount` (line 19), `minCacheExtent` (lines 175-182), `_cacheExtent` (lines 529-535), the direct-vs-transition check in `_startScroll` (lines 620-634).
- **Problem:** `_cacheExtent` is `max(viewportExtent × 2, minCacheExtent ?? 0)` on **each side** of the viewport. Flutter's default is 250 px. On an 800 px viewport, that's about 3,200 px of off-screen items built, laid out, registered and position-tracked on every frame, versus about 500 px for a `ListView`. Users can raise it through `minCacheExtent`, but they can't lower it. This is probably the largest steady-state cost in the package. It also multiplies the per-item cost in [task 19](19-lazy-position-computation.md).
- **Why it's this big:** `_startScroll` animates directly only when the target already has an `ItemPosition`, meaning it was built inside the cache extent. Otherwise it crossfades. The large cache makes "nearby" cover about two screens in each direction. Shrinking it means medium-distance `scrollTo` calls switch from a direct animation to a crossfade. **That is a visible behaviour change, so it needs owner approval.**
- **Options (pick with the owner):**
  1. **Opt-in large cache.** Default to the framework cache extent and keep today's behaviour behind a flag, or turn `minCacheExtent` into a full `cacheExtent` override.
  2. **Estimate nearby targets.** Use the normal cache extent. For a target outside the built items but within about two screens, estimate its offset from the average extent of the built items, `animateTo` that, then correct for the remaining error at the end, or re-target mid-animation when the item gets built. This keeps direct animation for medium distances. The risk is a small visible correction with variable-height items.
  3. **Don't raise the cache temporarily when `scrollTo` starts.** It looks attractive, but it builds about two screens of items in one frame, right at the start of the animation, which is the worst time for jank. Listed here so nobody picks it up without measuring.
- **Measure first:** using [task 22](22-device-profiling-harness.md), or the benchmark if no device is available, record the number of built items and the build/layout time per frame with today's cache extent versus 250 px. If the difference is small, close the task as "not worth it" and record the numbers here.
- **Acceptance:** before/after numbers recorded in this file. Tests that assert a direct animation for targets 1–2 screens away are updated only as far as the approved option requires. Changelog entry for the behaviour change.

## Measurements

"After" is a throwaway patch, not committed: `_cacheExtent` returns `max(250.0, minCacheExtent ?? 0)`, which is option 1 with the framework default. Nothing else changed.

- **Device:** Redmi Note 15 (`2510DRA23E`), Android 16, 120 Hz, the same device as the [task 22 baseline](22-device-profiling-harness.md#baseline)
- **Flutter:** 3.47.7 stable, profile mode, Impeller
- **Package commit:** `65d7a05`
- **Runs:** two per side, same build. Each table cell shows run 1 / run 2. Times are in ms.

### Build time (UI thread)

| scenario | frames before | frames after | build avg before | build avg after | build p99 before | build p99 after | build worst before | build worst after |
|---|---|---|---|---|---|---|---|---|
| drag_with_listener | 2279 / 2236 | 2515 / 2532 | 1.35 / 1.40 | 1.04 / 1.03 | 4.46 / 4.52 | 3.97 / 3.66 | 6.55 / 12.78 | 6.81 / 5.36 |
| drag_with_listener_separated | 2184 / 2188 | 2518 / 2524 | 1.61 / 1.60 | 1.16 / 1.13 | 4.94 / 5.03 | 3.95 / 3.90 | 11.73 / 15.31 | 11.04 / 7.27 |
| drag_without_listener | 2195 / 2201 | 2514 / 2517 | 1.52 / 1.54 | 1.09 / 1.10 | 4.62 / 4.74 | 3.63 / 3.63 | 7.77 / 11.47 | 6.32 / 6.76 |
| long_scroll_to | 593 / 600 | 730 / 736 | 4.51 / 4.36 | 2.94 / 2.83 | 69.96 / 71.89 | 28.91 / 30.96 | 83.04 / 81.17 | 37.32 / 41.78 |
| long_scroll_to_separated | 568 / 560 | 745 / 729 | 4.84 / 5.03 | 3.12 / 3.14 | 71.35 / 74.06 | 33.93 / 33.11 | 95.54 / 86.53 | 46.93 / 47.71 |
| short_scroll_to | 746 / 759 | 847 / 846 | 1.49 / 1.43 | 1.14 / 1.12 | 3.57 / 3.24 | 3.24 / 3.07 | 9.77 / 7.18 | 5.53 / 6.18 |

### Raster time and missed frames

| scenario | raster avg before | raster avg after | raster p99 before | raster p99 after | missed build before | missed build after | missed raster before | missed raster after |
|---|---|---|---|---|---|---|---|---|
| drag_with_listener | 3.39 / 3.60 | 3.21 / 3.27 | 6.88 / 7.29 | 6.71 / 6.34 | 0 / 0 | 0 / 0 | 0 / 1 | 0 / 1 |
| drag_with_listener_separated | 3.85 / 3.88 | 3.38 / 3.25 | 7.46 / 7.64 | 5.82 / 6.58 | 0 / 0 | 0 / 0 | 4 / 1 | 0 / 1 |
| drag_without_listener | 3.70 / 3.85 | 3.33 / 3.26 | 7.20 / 7.31 | 5.76 / 5.37 | 0 / 0 | 0 / 0 | 2 / 1 | 2 / 0 |
| long_scroll_to | 3.19 / 3.31 | 3.77 / 3.54 | 9.02 / 10.39 | 9.46 / 9.29 | 23 / 21 | 21 / 20 | 1 / 2 | 0 / 1 |
| long_scroll_to_separated | 3.22 / 3.46 | 3.92 / 3.83 | 10.52 / 10.14 | 8.51 / 9.00 | 23 / 26 | 20 / 22 | 2 / 0 | 0 / 0 |
| short_scroll_to | 3.56 / 3.74 | 3.29 / 3.27 | 6.61 / 6.65 | 5.46 / 5.50 | 0 / 0 | 0 / 0 | 0 / 1 | 0 / 0 |

### Built items

From a throwaway widget test: an 800 px viewport with 72 px items, positioned at index 500.

| | cache per side | items built and registered | positions computed per update (internal notifier) |
|---|---|---|---|
| before | 1,600 px | 57 | 57 |
| after | 250 px | 19 | 19 |

The public `itemPositionsListener` reports only the 12 visible items either way, because `_updatePositions` filters to the viewport. The internal primary notifier, which `_startScroll` uses for its direct-vs-crossfade check, holds every built item.

### What the numbers show

- **The gain is well outside run-to-run noise (5–10 %).** Average build time while dragging drops by about 25–30 % in every drag scenario, and both runs agree.
- **The long-scroll jank frame is roughly halved.** p99 goes from 70–74 ms to 29–34 ms and the worst frame from 81–96 ms to 37–48 ms, because the secondary list builds about a third as many items in its first frame. That frame is still over budget, so "missed build" stays around 20. The rest is [task 21](21-transition-cost.md).
- **About 13 % more frames are delivered in the same wall-clock time.** Drag scenarios go from about 2,200–2,280 frames to about 2,515–2,530. Fewer vsyncs are being skipped on the 120 Hz panel, which the fixed 16 ms "missed" counter doesn't show.
- **Raster time is flat or slightly better.** It is a little higher in the long scroll only because more frames now fall inside the measured window.
- **Behaviour cost:** with the plain 250 px patch, exactly 3 of the 204 tests fail, all of them the expected change: `Scroll to 20 without fading` (vertical and horizontal) and `Scroll to 20 without fading small minCacheExtent`. On this device the viewport is about 830 dp, so direct animation would shrink from about 2 screens beyond the viewport to about 0.3 screens.

## Recommendation

The gain is large enough that the task shouldn't be closed as "not worth it". The decision is how to handle the behaviour change.

**Recommended: option 1, in this shape:**

1. Add a nullable `cacheExtent` parameter to both constructors. When it's set, it's used as-is in both directions, so it can lower the cache as well as raise it. `minCacheExtent` keeps working as a floor, for compatibility.
2. When `cacheExtent` is null, default to the framework's 250 px. This is the behaviour change: `scrollTo` targets roughly 0.3–2 screens away now crossfade instead of animating directly. Add a changelog entry saying so, and saying how to restore the old feel. One way is `minCacheExtent`; the other is a `cacheExtent` the app computes, such as twice the viewport height.
3. Since the package is pre-1.0 (`0.4.0`), ship it as `0.5.0` with the "Unreleased" changelog items.
4. Update the 3 failing tests to pass an explicit large `cacheExtent`, so they still cover the direct-animation path. Add one test that a target outside the small default cache crossfades.

**Follow-up, optional:** option 2 (estimate nearby targets) can come later as its own task, to restore direct animation for medium distances without the cache cost. It's more complex and risks a visible correction with variable-height items, so it shouldn't block this.

**Alternative if no behaviour change is acceptable right now:** do only step 1 and keep today's default, so the change is purely additive and apps opt in. Then flip the default in a later breaking release. Most users would get none of the gain until then.

**Decisions needed from the owner:**

- (a) Option 1 as above, option 1 with no default change, or option 2.
- (b) If the default changes, whether `0.5.0` is the right version.
