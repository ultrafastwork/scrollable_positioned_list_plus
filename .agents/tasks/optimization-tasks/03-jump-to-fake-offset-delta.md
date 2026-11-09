# 3. `jumpTo` reports a fake offset delta — NEEDS OWNER DECISION

**Area:** correctness · **Line numbers:** `598e545`

**Status:** done in agent/list-state-followups — owner approved: reporting is suppressed during `_jumpTo`'s internal `jumpTo(0)` in both `recordProgrammaticScrolls` modes (`previousOffset` is still re-baselined). Patch applied and removed, regression test unskipped, changelog entry added.

- **File:** `lib/src/scrollable_positioned_list.dart`, `_jumpTo`
- **Problem:** `_jumpTo` calls `primary.scrollController.jumpTo(0)` to re-anchor the list. The offset listener reports this as a scroll of `-previousOffset` even though nothing moved visually. It's reported even when `recordProgrammaticScrolls` is `false`, because `_isTransitioning` is false at that point.
- **Fix direction:** set `previousOffset = 0` before the internal `jumpTo(0)`, or suppress reporting during it. Decide with the owner whether a `jumpTo` should report anything.
- **Acceptance:** with `recordProgrammaticScrolls: false`, `jumpTo` emits no delta. Existing offset tests pass.
