# 20. Fixed-extent mode (`itemExtent` / `prototypeItem`)

**Area:** performance (new public API) · **Line numbers:** `884e7c8`

**Status:** done. Owner decisions are recorded under [Owner decisions](#owner-decisions-2026-11-10), and the result under [Implementation](#implementation) and [Final measurements](#final-measurements). A `scrollTo` about 3.5 screens away went from a 60 ms hitch frame and 10–11 missed frames to a p99 of 6–8 ms with 0–1 missed. Dragging is unchanged.

## Owner decisions (2026-11-10)

- **(a) API:** `itemExtent` + `prototypeItem` on `.builder`, mutually exclusive (the recommendation).
- **(b) `.separated`:** add `separatorExtent` now. This goes against the recommendation, which was to leave it unsupported.
- **(c) Long distances:** animate directly up to about 10 viewports, and crossfade beyond that (the recommendation).

## Implementation

- **Public API** ([scrollable_positioned_list.dart](../../../lib/src/scrollable_positioned_list.dart)):
  - `.builder(itemExtent:, prototypeItem:)` asserts that the two aren't both set.
  - `.separated(itemExtent:, separatorExtent:)` asserts both or neither. `prototypeItem` isn't a parameter of `.separated`, so passing it is a compile error. A prototype together with a separator extent would need a prototype-measuring varied-extent sliver; that can follow if someone asks.
- **Slivers** ([positioned_list.dart](../../../lib/src/positioned_list.dart) `_sliver`): all three slivers (leading, center, trailing) use one of the following:
  - `SliverFixedExtentList` for `itemExtent`.
  - `SliverPrototypeExtentList` for `prototypeItem`.
  - The new `SliverAlternatingExtentList` for `.separated` with `separatorExtent` ([alternating_extent_list.dart](../../../lib/src/alternating_extent_list.dart)).
  - Without an extent, the plain `SliverList` is used as before.
- **Why a custom sliver for `.separated`:** Flutter's `SliverVariedExtentList` finds the child at a scroll offset by walking from index 0. That costs O(index) per layout, so it would get slower the deeper into a long list you scroll. `RenderSliverAlternatingExtentList` extends `RenderSliverFixedExtentBoxAdaptor` and overrides `indexToLayoutOffset`, the two `get*ChildIndexForScrollOffset` methods, `computeMaxScrollOffset` and `estimateMaxScrollOffset` with closed forms. In the leading sliver (built in reverse) and in the trailing sliver, items are the odd children. In the center sliver the single item is child 0.
- **`scrollTo`** (`_fixedExtentScrollOffset` and the check in `_startScroll`):
  - **Reading the extent and padding:** in fixed-extent mode each list's center `SliverPadding` gets a `GlobalKey` (`_ListDisplayDetails.centerKey`; `PositionedList.centerKey`). From its render object, `scrollTo` reads `beforePadding` and, for `prototypeItem`, the sliver's `itemExtent`.
    - Reading `beforePadding` from the render object instead of from `padding` means the result follows the axis direction the viewport actually uses, including RTL. When the anchor isn't item 0, `beforePadding` is 0, so the "padding only when `primary.target == 0`" rule falls out on its own.
  - **Target offset:** `(index − primary.target) × stride + beforePadding + (primary.alignment − alignment) × viewport`, clamped to `minScrollExtent`/`maxScrollExtent`. `stride` is `itemExtent + separatorExtent`. Both scroll extents are exact with fixed-extent slivers.
  - **Direct or crossfade:** if the offset is within `_maxDirectScrollScreens` (10) viewports of the current offset, the list animates straight there. Otherwise, and whenever the list isn't laid out yet, it falls back to the old logic: animate directly if the target is already built, else crossfade.
  - **The default path is unchanged:** without an extent, `centerKey` isn't passed and `_fixedExtentScrollOffset` returns null at once.
  - **Cache wiring:** `didUpdateWidget` already clears the cached `PositionedList`s, so changing `itemExtent`/`prototypeItem`/`separatorExtent` on a live list takes effect. The `_positionedList` cache check doesn't need the new fields.
- **Tests** ([test/fixed_extent_scrollable_positioned_list_test.dart](../../../test/fixed_extent_scrollable_positioned_list_test.dart)): 36 tests, 12 for each mode (`itemExtent`, `prototypeItem`, `separated`).
  - **What they cover:** items forced to the extent; alignment 0/0.5/1 forward into the trailing sliver and back into the leading sliver; horizontal; reversed; padding with the anchor at 0 and at 5 (including the clamp at the start); the last item (the clamp at the end); `shrinkWrap`; a target beyond the cap still crossfades; dragging through both slivers keeps a constant stride.
  - **How "no crossfade" is checked:** every within-cap scroll checks on each frame that only one `FadeTransition` exists, so `_isTransitioning` never became true.
  - **Sanity check:** with the cap temporarily set to 0, 30 of the 36 tests fail.
- **Results:** `flutter test` gives 244 passed (208 + 36). `flutter analyze` (package and example) reports no issues.
- **Docs:** a README section, "Fixed-height items", and a changelog entry under Unreleased.
- **Harness** ([example/integration_test/perf_test.dart](../../../example/integration_test/perf_test.dart)): new scenarios are `medium_scroll_to` on the default path, plus `fixed_drag_with_listener`, `fixed_short_scroll_to`, `fixed_medium_scroll_to`, `fixed_medium_scroll_to_separated`, `fixed_9_screens_scroll_to` and `fixed_long_scroll_to`. The hybrid "jump, then animate" scenario was dropped (rejected).
- **Untested:** RTL horizontal lists with `padding` while the anchor isn't item 0. `PositionedList` assigns left/right padding by `reverse` only, not by text direction, so the padding may land between items there. That's existing behaviour and not specific to this task.

## Final measurements

- **Device and toolchain:** the same as in the prototype measurements below: Redmi Note 15, Flutter 3.47.7, profile mode, `--no-dds`.
- **Code:** the final implementation on top of `884e7c8`.
- **Runs:** two full runs, A / B. Times are in ms, and missed frames are counted over 10 scrolls.
- **Viewport:** inside `SafeArea` it is under 792 px. Two earlier runs showed that targets 110 and 120 items away (7,920 and 8,640 px) are already over the cap and crossfade. Their numbers matched `long_scroll_to`, which confirms the cap works. The "about 10 screens" scenario was therefore moved to 100 items (7,200 px), just under the cap.

| scenario | distance | path | frames | build avg | build p99 | build worst | missed build |
|---|---|---|---|---|---|---|---|
| drag_with_listener | – | default | 2286 / 2288 | 1.34 / 1.34 | 4.23 / 4.20 | 8.07 / 9.49 | 0 / 0 |
| fixed_drag_with_listener | – | `itemExtent` | 2272 / 2209 | 1.42 / 1.50 | 4.29 / 4.42 | 15.72 / 10.40 | 0 / 0 |
| short_scroll_to | 12 items | default (direct, in cache) | 795 / 773 | 1.40 / 1.42 | 3.49 / 3.27 | 7.15 / 6.11 | 0 / 0 |
| fixed_short_scroll_to | 12 items | `itemExtent`, direct | 768 / 775 | 1.42 / 1.42 | 3.28 / 3.24 | 7.04 / 5.91 | 0 / 0 |
| medium_scroll_to | 40 items, ~3.5 screens | default (crossfade) | 670 / 674 | 3.44 / 3.35 | 62.13 / 63.63 | 74.99 / 74.61 | 11 / 10 |
| fixed_medium_scroll_to | 40 items | `itemExtent`, direct | 671 / 623 | 2.30 / 2.63 | 6.43 / 7.63 | 10.04 / 16.12 | 0 / 1 |
| fixed_medium_scroll_to_separated | 40 items | `itemExtent` + `separatorExtent`, direct | 662 / 644 | 2.59 / 2.69 | 8.25 / 11.65 | 19.03 / 14.70 | 1 / 0 |
| fixed_9_screens_scroll_to | 100 items, ~9 screens | `itemExtent`, direct | 584 / 596 | 3.79 / 3.74 | 14.09 / 12.10 | 22.77 / 17.97 | 3 / 1 |
| long_scroll_to | 4,900 items | default (crossfade) | 644 / 655 | 3.50 / 3.54 | 61.10 / 59.08 | 67.42 / 83.57 | 12 / 11 |
| fixed_long_scroll_to | 4,900 items | `itemExtent`, beyond the cap → crossfade | 648 / 666 | 3.56 / 3.39 | 62.92 / 62.95 | 92.10 / 69.15 | 12 / 11 |

What the final numbers show:

- **Medium distance is the win.** At about 3.5 screens, p99 build falls from 62–64 ms to 6–8 ms and missed frames from 10–11 to 0–1. The separated variant behaves the same.
- **The cap is about right after task 21.** Task 21 cut the crossfade to about 11 missed frames with a roughly 60 ms hitch. At 9 screens the direct path misses 1–3 frames and never goes over 23 ms. The prototype's 20-screen direct run missed 32. So 10 viewports is still on the right side of the crossover.
- **Beyond the cap, nothing changes:** `fixed_long_scroll_to` matches `long_scroll_to`.
- **Dragging is unchanged** (within run-to-run noise), as the prototype predicted.
- **Short scrolls are unchanged:** both paths animate directly.

- **Files:** `lib/src/scrollable_positioned_list.dart` (constructors at lines 40 and 66, `didUpdateWidget` lines 436-480, `_buildList` lines 512-527, `_positionedList` lines 536-566, `_startScroll` lines 640-790 with the direct-vs-transition check at lines 659-674), `lib/src/positioned_list.dart` (`build` lines 171-255, the three `SliverList`s at lines 191, 210 and 229), `README.md`, `CHANGELOG.md`, `example/`.
- **Wiring after task 21:** `PositionedList` widgets are now cached per list in `_positionedList`, and its cache check compares only `positionedIndex`, `alignment` and `cacheExtent`. `didUpdateWidget` clears both cached lists (lines 468-469), so a changed `itemExtent`/`prototypeItem` still reaches the list without touching the cache check; just pass the new parameters through in the `PositionedList(...)` call. The fixed-extent direct path belongs in the `itemPosition != null` branch's condition at lines 662-674 (direct when within the cap), leaving the crossfade branch untouched.
- **Opportunity:** when every item has the same main-axis extent, the offset of any item is `index × extent`. So:
  - **`scrollTo` never needs the crossfade.** Compute the target offset and `animateTo` it on the primary list, with no secondary list, no opacity layers and no dependency on the cache extent ([task 18](18-default-cache-extent.md)).
  - **Layout is cheaper.** `SliverFixedExtentList` (or `SliverPrototypeExtentList`) doesn't measure children to place them.
  - **Positions are pure arithmetic** ([task 19](19-lazy-position-computation.md), part B, becomes trivial on this path).
  Chat logs, settings screens and tables often have fixed-height rows, so this would be the fastest path for a common case.
- **Owner decisions:**
  - API names. Mirror `ListView` with `itemExtent` and `prototypeItem` (mutually exclusive).
  - Whether `.separated` supports it. Separators would need their own fixed extent (for example `separatorExtent`). The simplest start is `.builder` only, with an assert.
  - Whether a long `animateTo` over thousands of items is acceptable. It builds items for every frame it passes through, like a `ListView`. The alternative is to jump to within a screen of the target and animate the rest.
- **Fix direction:**
  - In `PositionedList`, use `SliverFixedExtentList`/`SliverPrototypeExtentList` for the leading, center and trailing slivers when an extent is given.
  - In `_startScroll`, work in the primary's coordinate system, where offset 0 puts item `primary.target`'s leading edge at `primary.alignment`. The target offset is `(index - primary.target) × extent + (primary.alignment - alignment) × viewportDimension`, adjusted for `padding`, then clamped to `minScrollExtent`/`maxScrollExtent`.
    - Padding only matters when `primary.target == 0`: the center sliver then carries the leading padding, so every item sits that much further on. Otherwise the leading padding is at the far end of the leading sliver and lies outside the range of items between the anchor and the target. The trailing padding only affects `maxScrollExtent`, which the clamp already covers.
- **Acceptance:** new tests for vertical, horizontal, reversed, padding, alignment 0/0.5/1, the last item (clamping) and `shrinkWrap`. They check the final positions and that `_isTransitioning` never becomes true (or, with the recommended distance cap, never becomes true below the cap). Existing tests pass unchanged, since the default path is untouched. Benchmark numbers for "long `scrollTo`" and "drag" with and without `itemExtent` are recorded here. README and changelog document the new parameters.

## Prototype measurements (before the owner decisions)

**Prototype** (throwaway, not committed):
- `.builder` gets `itemExtent`, and `PositionedList` uses `SliverFixedExtentList` for all three slivers when it's set.
- `_startScroll` takes the arithmetic path above, without padding handling, and always animates directly.
- A debug switch makes targets more than 2 screens away jump to 2 screens out first and animate the rest. This is the "jump, then animate" alternative from the third decision.

The harness ran with extra scenarios:
- The same list with `itemExtent: 72`. The `ListTile` is 72 px anyway, so the items are identical.
- A new `medium_scroll_to` on the default path.

Every `scrollTo` takes 600 ms with `Curves.linear`. The viewport is about 830 dp.

- **Device:** Redmi Note 15 (`2510DRA23E`), Android 16, 120 Hz, the same device as the [task 22 baseline](22-device-profiling-harness.md#baseline)
- **Flutter:** 3.47.7 stable, profile mode, Impeller
- **Package commit:** `89c3433`
- **Runs:** two, same build. Cells show run 1 / run 2 ("–" = run 2 only). Times are in ms. Raster time was flat (3–4 ms average) everywhere and isn't shown.

| scenario | distance | path | frames | build avg | build p99 | build worst | missed build |
|---|---|---|---|---|---|---|---|
| drag_with_listener | – | default | 2283 / 2222 | 1.35 / 1.40 | 4.42 / 4.43 | 13.49 / 13.83 | 0 / 0 |
| fixed_drag_with_listener | – | `itemExtent` | 2238 / 2201 | 1.46 / 1.50 | 4.46 / 4.52 | 6.90 / 13.97 | 0 / 0 |
| short_scroll_to | 12 items, ~1 screen | default (direct, in cache) | 782 / 721 | 1.36 / 1.51 | 3.31 / 3.68 | 6.79 / 6.59 | 0 / 0 |
| fixed_short_scroll_to | 12 items, ~1 screen | `itemExtent`, direct | 772 / 772 | 1.39 / 1.40 | 3.21 / 3.22 | 4.32 / 7.93 | 0 / 0 |
| medium_scroll_to | 40 items, ~3.5 screens | default (crossfade) | 592 / 571 | 4.41 / 4.51 | 68.92 / 69.81 | 81.95 / 83.97 | 21 / 22 |
| fixed_medium_scroll_to | 40 items, ~3.5 screens | `itemExtent`, direct | 623 / 681 | 2.59 / 2.40 | 6.89 / 7.47 | 13.22 / 14.45 | 0 / 0 |
| fixed_10_screens_scroll_to | 120 items, ~10 screens | `itemExtent`, direct | – / 505 | – / 4.90 | – / 17.55 | – / 22.95 | – / 8 |
| fixed_20_screens_scroll_to | 230 items, ~20 screens | `itemExtent`, direct | – / 385 | – / 8.56 | – / 28.55 | – / 40.19 | – / 32 |
| long_scroll_to | 4,900 items, ~425 screens | default (crossfade) | 621 / 577 | 4.21 / 4.71 | 69.39 / 73.06 | 86.24 / 82.60 | 22 / 28 |
| fixed_long_scroll_to | 4,900 items, ~425 screens | `itemExtent`, direct | 157 / 141 | 32.57 / 37.62 | 93.89 / 88.14 | 103.82 / 103.69 | 84 / 86 |
| fixed_long_scroll_to_hybrid2 | 4,900 items, ~425 screens | `itemExtent`, jump to 2 screens out, then animate | 622 / 638 | 2.97 / 3.00 | 63.05 / 66.69 | 79.82 / 91.96 | 10 / 10 |

### What the numbers show

- **Fixed-extent layout gives no measurable gain while dragging.** Build averages of 1.46 / 1.50 ms against 1.35 / 1.40 ms are within run-to-run noise. Per-frame cost is dominated by building items into the large cache extent ([task 18](18-default-cache-extent.md)), not by measuring them. The "layout is cheaper" bullet doesn't hold up on this device.
- **The real win is medium-distance `scrollTo`.** At about 3.5 screens, the default path crossfades and has a 70 ms hitch frame with about 21 missed frames per 10 scrolls. The fixed-extent direct animation has p99 7 ms and no missed frames, and it lands exactly. This is the range users notice most: "jump to the section below".
- **A direct `animateTo` over a long distance is unusable.** Over 4,900 items, the frame rate collapses to about 15 fps for the whole animation (141–157 frames over 6 s, 84–86 missed). Every frame builds a new viewport plus cache of items. This rules out "always animate directly".
- **The crossover is between 10 and 20 screens** (for a 600 ms scroll on this device). At 10 screens the direct path still beats the crossfade on every metric (8 missed, worst 23 ms, against about 22 missed and an 80 ms hitch). At 20 screens it misses more frames than the crossfade (32), although it never has a single long hitch.
- **Task 21 has since made the crossfade cheaper** (about a third fewer dropped vsyncs, worst frame about 15–20 % lower). The default-path rows above predate it, so the crossover may sit nearer 10 screens than 20. Re-measure `medium_scroll_to`, `long_scroll_to` and `fixed_10_screens_scroll_to` on top of task 21 before fixing the cap.
- **"Jump to 2 screens out, then animate" isn't worth it.** The jump frame costs as much as the crossfade's first frame (p99 63–67 ms), because it builds a fresh viewport and cache in one frame. It misses fewer frames than the crossfade (10 against 22–28) only because there's one list, not two. And with no fade, the jump is a visible teleport.

## Recommendation

Do the task, but narrower than the original pitch. The value is exact, crossfade-free `scrollTo` for short and medium distances, not cheaper layout.

1. **API:** add `itemExtent` and `prototypeItem` to `.builder`, mirroring `ListView`, with an assert that they're mutually exclusive.
   - With `prototypeItem`, read the extent at scroll time from the laid-out sliver. The center sliver's render object is a `RenderSliverFixedExtentBoxAdaptor`, whose `itemExtent` is public. Or read it from the size of any built item.
   - Both use `SliverFixedExtentList`/`SliverPrototypeExtentList` for all three slivers. They don't make drag faster, but they keep `index × extent` true by construction, even if an item's own size disagrees.
2. **`.separated`:** not supported in the first version. Leave the parameters off the `.separated` constructor entirely, rather than asserting, so misuse is a compile error. A `separatorExtent` can follow later if someone asks for it.
3. **Long distances:** animate directly only when the target is within a cap, and above the cap keep today's crossfade. The crossfade already lands exactly, so nothing is lost.
   - Suggested cap: **10 viewports**, as a private constant. It's the largest measured distance where the direct path beats the crossfade on every metric.
   - Do **not** use "jump, then animate".
   - The acceptance criterion becomes "`_isTransitioning` never becomes true for targets within the cap". Add one test that a target beyond the cap still crossfades.
4. **Harness:** keep the `fixed_*` scenarios above in `example/integration_test/perf_test.dart`, without the hybrid one, plus `medium_scroll_to` for the default path. The medium scenario is also the one that shows the cost of [task 18](18-default-cache-extent.md) option 1.
5. **Version:** the change is purely additive, since nothing changes without the new parameters. It can ship in the same minor release as the "Unreleased" items, with a changelog entry and a README section.

**Note for the owner:** [task 18](18-default-cache-extent.md) option 2 ("estimate nearby targets") would bring direct medium-distance scrolls to *all* lists, with a possible end-of-scroll correction for variable heights. This task is the exact version of the same idea for fixed-height lists. The two don't conflict.

**Decisions needed from the owner** (answered on 2026-11-10; see [Owner decisions](#owner-decisions-2026-11-10)):

- (a) API: `itemExtent` + `prototypeItem` on `.builder` only, as above? Or `itemExtent` only for a first version?
- (b) `.separated`: unsupported for now (recommended), or add `separatorExtent` now?
- (c) Long distances: direct animation up to a cap of about 10 viewports, crossfade beyond (recommended)? Or always direct (measured above at about 15 fps over long distances), or "jump, then animate" (rejected above)?
