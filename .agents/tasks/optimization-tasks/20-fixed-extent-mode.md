# 20. Fixed-extent mode (`itemExtent` / `prototypeItem`) — NEEDS OWNER DECISION

**Area:** performance (new public API) · **Line numbers:** `89c3433`

**Status:** blocked on owner decision. A throwaway prototype was measured on the device (below). No code has changed. Answer the questions under [Recommendation](#recommendation) to unblock.

- **Files:** `lib/src/scrollable_positioned_list.dart` (constructors, `_buildList` lines 508-541, `_startScroll` lines 615-704), `lib/src/positioned_list.dart` (`build` lines 171-247), `README.md`, `CHANGELOG.md`, `example/`.
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

## Measurements

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

**Decisions needed from the owner:**

- (a) API: `itemExtent` + `prototypeItem` on `.builder` only, as above? Or `itemExtent` only for a first version?
- (b) `.separated`: unsupported for now (recommended), or add `separatorExtent` now?
- (c) Long distances: direct animation up to a cap of about 10 viewports, crossfade beyond (recommended)? Or always direct (measured above at about 15 fps over long distances), or "jump, then animate" (rejected above)?
