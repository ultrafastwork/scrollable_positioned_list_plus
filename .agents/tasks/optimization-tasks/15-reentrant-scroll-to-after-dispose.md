# 15. Re-entrant `scrollTo` runs on a disposed list — verify before fixing

**Area:** correctness · **Line numbers:** `ef8d53e`

**Status:** done in agent/list-state-followups — reproduced (`_startScroll` hit `'_positions.isNotEmpty'` on the disposed controller and the future hung); the deferred callback now completes `scrollCompleter` and returns when `!mounted`.

- **File:** `lib/src/scrollable_positioned_list.dart`, `_scrollTo`, the `_isTransitioning` branch (~line 557 at `ef8d53e`)
- **Suspected problem:** a `scrollTo` issued while a transition is running cancels it and calls `_startScroll` from a post-frame callback with no `mounted` check. If the list is disposed before that callback runs, `_startScroll` touches the disposed controllers and `scrollCompleter` never completes, so `await scrollTo(...)` hangs.
- **Fix direction:** in that callback, if `!mounted`, complete `scrollCompleter` and return. Write a reproducing test first; mark "not reproduced" if it can't be hit.
