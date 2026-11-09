# 2. `scrollTo` future can never complete

**Area:** correctness · **Line numbers:** `598e545`

**Status:** done in agent/list-state — pending start completers are kept in state and completed (stale `startAnimationCallback` reset) by `_stopScroll`; a transition id stops a superseded scroll from stopping its successor.

- **File:** `lib/src/scrollable_positioned_list.dart`, `_startScroll` (~line 570) and `_stopScroll` (~line 645)
- **Problem:** in the long-distance path, `startCompleter` and `endCompleter` are only completed inside `startAnimationCallback`. That callback only runs when the secondary list's `PostMountCallback` mounts. If `_stopScroll(canceled: true)` runs (pointer-down, `jumpTo`, or a new `scrollTo`) after `setState(_isTransitioning = true)` but before the next frame builds the secondary list, the secondary list is never mounted. The awaited `Future.wait` then never completes, so the caller's `await scrollTo(...)` hangs. The stale `startAnimationCallback` also stays set and may fire on an unrelated later mount.
- **Fix direction:** keep the pending completers (or a single "pending start" handle) in state. In `_stopScroll`, if the start callback hasn't run yet, reset `startAnimationCallback = () {}` and complete the pending completers. Look at the re-entrancy `TODO` at ~line 627 at the same time.
- **Acceptance:** a test that calls `scrollTo(index: far)` and then, before pumping, cancels with `jumpTo` or a pointer-down. The returned future must complete after `pumpAndSettle`.
