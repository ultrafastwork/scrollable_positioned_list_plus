# 17. `jumpTo` lands past the target after a manual scroll with variable heights (google/flutter.widgets#144)

**Area:** correctness (previously skipped upstream test, now unskipped)

**Status:** done on `main`. After dragging to offset 2000, `jumpTo(100)` ended at offset 115 with item 101 at the top. Cause: jumping from index 0 changes the slivers from `[center, trailing]` to `[leading, center, trailing]`, and the unkeyed trailing `SliverPadding` was matched to the old one, so its `RenderSliverList` kept layout offsets from items 1–499 and applied a bogus scroll-offset correction. Fixed-height items hid this because the stale offsets happened to be right. The leading and trailing slivers are now keyed by `positionedIndex`, so a re-anchor builds fresh slivers. The scroll benchmark shows no difference beyond run-to-run noise (±10%).

- **File:** `lib/src/positioned_list.dart`, `build`
