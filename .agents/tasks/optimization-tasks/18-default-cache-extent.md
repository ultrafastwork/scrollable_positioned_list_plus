# 18. Shrink the default cache extent — owner decided: option 1, default 250 px, 0.5.0

**Area:** performance · **Line numbers:** `fddbc8c`

**Status:** done. New nullable `cacheExtent` on both constructors; the default is `RenderAbstractViewport.defaultCacheExtent` (250 px), and `minCacheExtent` is still a floor. Released as `0.5.0` (changelog and README updated). On device, on top of tasks 20 and 21: build time while dragging is about 20 % lower and long `scrollTo` p99 build time drops from 51–64 ms to 20–36 ms. See [Result](#result).

## Owner decision (2026-11-10)

- (a) **Option 1 as recommended:** add `cacheExtent` and change the default to the framework's 250 px.
- (b) **Version `0.5.0`**: the "Unreleased" changelog items move under it.

- **Files:** `lib/src/scrollable_positioned_list.dart`: `_screenScrollCount` (line 19), `minCacheExtent` (constructors at lines 59 and 86, field at line 182), `_cacheExtent` (lines 568-574), `_positionedList` (lines 536-566), the direct-vs-transition check in `_startScroll` (lines 659-674).
- **Wiring after task 21:** `_cacheExtent` is computed in `build` (line 486) and passed into `_positionedList`, whose cache check already compares `cacheExtent` (line 544). A new `cacheExtent` parameter only has to feed `_cacheExtent`; no `didUpdateWidget` change is needed for it to reach the list. `_screenScrollCount` is also the crossfade's jump distance (lines 675-677, 698-700). That's independent of the cache size, so it can stay as it is.
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
- **The long-scroll jank frame is roughly halved.** p99 goes from 70–74 ms to 29–34 ms and the worst frame from 81–96 ms to 37–48 ms, because the secondary list builds about a third as many items in its first frame. That frame is still over budget, so "missed build" stays around 20. The rest is [task 21](21-transition-cost.md) (now done; these numbers predate it, so re-measure on top of it when implementing).
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

**Decisions needed from the owner:** answered, see [Owner decision](#owner-decision-2026-11-10).

## Result

**What changed** (`lib/src/scrollable_positioned_list.dart`):

- `cacheExtent` field and constructor parameter on `.builder` and `.separated`.
- `_cacheExtent` is `max(cacheExtent ?? 250, minCacheExtent ?? 0)`. It no longer depends on the viewport size, so the `LayoutBuilder` that wrapped `build` (used only for this) is gone.
- `_screenScrollCount` stays, because it's still the crossfade's jump distance.

**Tests:** 248 passed, 0 skipped (the 244 baseline plus 4 new tests). `flutter analyze` reports no issues.

- `Scroll to 20 without fading` (vertical and horizontal) and `Scroll to 20 without fading small minCacheExtent` now pass `cacheExtent: 2 × viewport`, so they still cover the direct path. The last one also checks that a small `minCacheExtent` doesn't lower the cache.
- The new tests cover the 250 px default (item 16 is built and item 17 isn't), `cacheExtent: 0` lowering the cache, `minCacheExtent` raising a smaller `cacheExtent`, and `Scroll to 20` crossfading with the default.

**Device numbers:** Redmi Note 15, Flutter 3.47.7, profile mode. Both sides were built from the same tree: "before" is `9a5b746` with `lib/` stashed, "after" is this change. Two runs per side, shown as run 1 / run 2. Times are in ms.

| scenario | frames before | frames after | build avg before | build avg after | build p99 before | build p99 after | build worst before | build worst after | missed build before | missed build after |
|---|---|---|---|---|---|---|---|---|---|---|
| drag_with_listener | 2321 / 2300 | 2531 / 2497 | 1.27 / 1.34 | 0.99 / 1.11 | 4.12 / 4.34 | 3.59 / 3.98 | 10.09 / 6.07 | 7.04 / 6.45 | 0 / 0 | 0 / 0 |
| drag_with_listener_separated | 2276 / 2308 | 2514 / 2505 | 1.48 / 1.45 | 1.16 / 1.23 | 4.71 / 4.65 | 4.09 / 4.30 | 8.13 / 7.04 | 6.23 / 5.42 | 0 / 0 | 0 / 0 |
| drag_without_listener | 2283 / 2268 | 2520 / 2505 | 1.41 / 1.44 | 1.11 / 1.14 | 4.36 / 4.40 | 3.78 / 4.10 | 8.21 / 14.16 | 8.81 / 8.94 | 0 / 0 | 0 / 0 |
| short_scroll_to | 792 / 786 | 836 / 843 | 1.34 / 1.40 | 1.13 / 1.14 | 3.22 / 3.50 | 3.36 / 2.96 | 6.99 / 6.97 | 6.21 / 6.70 | 0 / 0 | 0 / 0 |
| medium_scroll_to | 700 / 684 | 794 / 763 | 3.11 / 3.29 | 2.29 / 2.55 | 53.89 / 60.57 | 32.85 / 36.72 | 68.95 / 68.74 | 49.52 / 55.02 | 12 / 12 | 10 / 10 |
| long_scroll_to | 684 / 659 | 752 / 724 | 3.18 / 3.50 | 2.61 / 2.93 | 59.11 / 59.15 | 26.38 / 35.97 | 64.42 / 86.24 | 46.19 / 58.86 | 10 / 12 | 10 / 10 |
| long_scroll_to_separated | 657 / 635 | 775 / 720 | 3.61 / 3.88 | 2.69 / 3.06 | 58.53 / 63.63 | 31.75 / 35.38 | 72.33 / 72.09 | 64.11 / 55.95 | 12 / 12 | 11 / 10 |
| fixed_drag_with_listener | 2313 / 2272 | 2519 / 2515 | 1.36 / 1.42 | 1.09 / 1.13 | 4.20 / 4.37 | 3.77 / 3.96 | 8.13 / 7.95 | 4.66 / 12.28 | 0 / 0 | 0 / 0 |
| fixed_short_scroll_to | 774 / 793 | 843 / 831 | 1.39 / 1.35 | 1.10 / 1.14 | 3.22 / 3.19 | 2.65 / 2.80 | 4.48 / 5.20 | 7.65 / 5.29 | 0 / 0 | 0 / 0 |
| fixed_medium_scroll_to | 659 / 705 | 834 / 822 | 2.33 / 2.25 | 1.74 / 1.81 | 6.59 / 6.79 | 5.38 / 4.84 | 16.47 / 9.81 | 11.88 / 11.13 | 1 / 0 | 0 / 0 |
| fixed_medium_scroll_to_separated | 667 / 632 | 829 / 821 | 2.50 / 2.62 | 1.89 / 1.92 | 8.66 / 7.20 | 4.55 / 4.76 | 15.93 / 12.62 | 16.39 / 11.41 | 0 / 0 | 1 / 0 |
| fixed_9_screens_scroll_to | 605 / 612 | 576 / 588 | 3.49 / 3.68 | 4.46 / 4.42 | 12.11 / 14.95 | 11.50 / 11.96 | 20.61 / 25.57 | 19.93 / 19.72 | 3 / 5 | 4 / 2 |
| fixed_long_scroll_to | 672 / 639 | 749 / 753 | 3.00 / 3.47 | 2.56 / 2.65 | 51.20 / 58.12 | 26.63 / 20.31 | 72.25 / 69.86 | 35.38 / 38.22 | 10 / 14 | 10 / 11 |

**Raster:** the average went from 2.9–3.8 ms to 3.1–4.2 ms. It's a little higher in the `scrollTo` scenarios, partly because more frames now fall inside the measured window. p99 raster is roughly flat, and missed raster frames fell from 0–4 to 0–1 per scenario. The raw output is in each run's `example/build/perf/` summaries (not committed).

**What the numbers show:**

- **Dragging:** average build time is down about 20 % in every drag scenario, fixed-extent included, and about 9 % more frames are delivered in the same time (about 2,300 → 2,500).
- **Crossfading `scrollTo`** (`medium`, `long`, `fixed_long`): p99 build time drops from 51–64 ms to 20–37 ms and the worst frame by about 10–50 %. Missed build frames drop slightly, from 10–14 to 10–11. `medium_scroll_to` (about 3.5 screens) crossfaded before too, so it shows the gain rather than the cost of this change. The README's earlier note that it would show the cost was wrong.
- **Fixed-extent direct `scrollTo`:** `fixed_medium` improves (avg 2.3 → 1.8 ms, p99 6.6–6.8 → 4.8–5.4 ms). `fixed_9_screens_scroll_to` is the one scenario where average build is higher (3.5–3.7 → 4.4–4.5 ms) with slightly fewer frames, but p99, worst frame and missed frames are unchanged or better. That's acceptable, but worth watching if someone tunes `_maxDirectScrollScreens`.
- **Not measured:** the behaviour change itself. A target 0.3–2 screens past the viewport used to animate directly and now crossfades. No harness scenario covers that range, because `short_scroll_to` stays inside the cache and `medium_scroll_to` was already past it. Expect its per-scroll cost to look like the "after" `medium_scroll_to` row. Option 2 (estimate nearby targets) is still open as a possible follow-up task.
