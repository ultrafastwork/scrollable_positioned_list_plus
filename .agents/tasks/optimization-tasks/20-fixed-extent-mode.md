# 20. Fixed-extent mode (`itemExtent` / `prototypeItem`) — NEEDS OWNER DECISION

**Area:** performance (new public API) · **Line numbers:** `a0ee16b`

**Status:** not started.

- **Files:** `lib/src/scrollable_positioned_list.dart` (constructors, `_buildList` lines 494-527, `_startScroll` lines 601-690), `lib/src/positioned_list.dart` (`build` lines 171-247), `README.md`, `CHANGELOG.md`, `example/`.
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
- **Acceptance:** new tests for vertical, horizontal, reversed, padding, alignment 0/0.5/1, the last item (clamping) and `shrinkWrap`. They check the final positions and that `_isTransitioning` never becomes true. Existing tests pass unchanged, since the default path is untouched. Benchmark numbers for "long `scrollTo`" and "drag" with and without `itemExtent` are recorded here. README and changelog document the new parameters.
