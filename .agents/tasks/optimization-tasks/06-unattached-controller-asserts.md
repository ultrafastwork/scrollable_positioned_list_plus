# 6. Calls on an unattached controller give unhelpful errors

**Area:** correctness · **Line numbers:** `598e545`

**Status:** done in agent/list-state — added "is not attached to a ScrollablePositionedList" asserts to `ItemScrollController.jumpTo` and `ScrollOffsetController.animateScroll` (debug-only).

- **File:** `lib/src/scrollable_positioned_list.dart`, `ItemScrollController.jumpTo` and `ScrollOffsetController.animateScroll`
- **Problem:** both dereference `_scrollableListState!` with no assert. A caller who forgot to attach the controller gets a bare null-check error. `scrollTo` already has an assert.
- **Fix:** add `assert(_scrollableListState != null, '... is not attached to a ScrollablePositionedList')` to both. Debug-only, so there's no behaviour change in release.
