# 9. Skip redundant `_updatePositions` work for the hidden secondary list

**Area:** performance · **Line numbers:** `598e545`

**Status:** done in agent/list-state — one position listener per `_ListDisplayDetails` that only calls `_updatePositions` when its list is the current primary (128 → ≤ 77 updates over a 76-frame transition); the post-swap explicit call was added in task 8.

- **File:** `lib/src/scrollable_positioned_list.dart`: `_updatePositions` listens to both the primary and secondary internal notifiers.
- **Problem:** while transitioning, every secondary-list frame re-filters the primary's positions, rewrites `PageStorage` and re-notifies the user, even though primary positions didn't change in that callback.
- **Fix direction:** register separate listeners per `_ListDisplayDetails`, as was done for scroll controllers in `598e545`. Only recompute when the source notifier belongs to the current `primary`. After the swap in `_stopScroll`, call `_updatePositions()` once explicitly so the user immediately sees the new primary's positions.
- **Low priority.** Do it after task 8, and only if it stays simple.
