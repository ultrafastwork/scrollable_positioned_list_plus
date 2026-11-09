# scrollable_positioned_list_plus — performance & correctness task list

Repo: https://github.com/ultrafastwork/scrollable_positioned_list_plus (branch `main`, base commit `598e545`).
Flutter package; all source is in `lib/src/`, tests in `test/`.

## Ground rules for every task

- **Don't break existing behaviour.** On `598e545`, `flutter test` gives 182 passed and 2 skipped. That must still hold after your change, and `flutter analyze` must report no issues.
- **Prove the bug first.** For a correctness task, add a regression test that fails on `598e545` and passes with your fix. Check this by stashing `lib/`, running the test, then restoring.
- **Ask before changing public behaviour.** If a task is marked **NEEDS OWNER DECISION**, don't change observable behaviour without the owner's approval. Implement it behind the approved option only.
- **Keep commits small.** Make one commit per task, and don't touch unrelated code.
- **Watch for file conflicts.** Tasks 2, 3, 4, 6, 8 and 9 all edit `lib/src/scrollable_positioned_list.dart`, so give them to one agent or do them one after another. Tasks 8 and 9 both change position reporting, so do 8 first. Tasks 7 and 10 both edit `lib/src/wrapping.dart`, so pair them too. Task 1, task 5 and the 7+10 pair touch different files from each other and from the group above, so they can run in parallel.
- **Line numbers** are for `598e545`.

## Already fixed in 598e545 (don't redo)

The scroll-offset listener now survives the list swap. `ScrollOffsetController` is re-attached in `didUpdateWidget`. Index is clamped. `PageStorage.maybeOf` is used. The post-frame callback has `mounted`/`hasClients` guards. Controllers and notifiers are disposed. The registry `updateShouldNotify` no longer always returns `true`. Positions are materialized once, the `ReverseAnimation` is cached, and redundant `setState` calls are gone.

---

## Correctness

### 1. `ScrollOffsetListener` buffers events without limit — NEEDS OWNER DECISION
**Status:** done in agent/list-state-followups — owner approved; `StreamController<double>.broadcast()`, doc comment on `changes` updated, changelog entry added. Regression test: two listeners both receive deltas (the second `listen` threw "Stream has already been listened to" before).
- **File:** `lib/src/scroll_offset_notifier.dart:12`
- **Problem:** `StreamController<double>()` creates a single-subscription stream. If a `ScrollOffsetListener` is passed to the list but nobody calls `changes.listen` (or listens late), every scroll delta is buffered in memory forever. A second `listen` throws.
- **Proposed fix:** `StreamController<double>.broadcast()`.
- **Behaviour change:** events emitted before anyone listens are dropped, not replayed, and multiple listeners become allowed. Get owner approval, then add a changelog entry.
- **Acceptance:** add a test that two listeners both receive deltas. Existing `test/scroll_offset_listener_test.dart` still passes.

### 2. `scrollTo` future can never complete
**Status:** done in agent/list-state — pending start completers are kept in state and completed (stale `startAnimationCallback` reset) by `_stopScroll`; a transition id stops a superseded scroll from stopping its successor.
- **File:** `lib/src/scrollable_positioned_list.dart`, `_startScroll` (~line 570) and `_stopScroll` (~line 645)
- **Problem:** in the long-distance path, `startCompleter` and `endCompleter` are only completed inside `startAnimationCallback`. That callback only runs when the secondary list's `PostMountCallback` mounts. If `_stopScroll(canceled: true)` runs (pointer-down, `jumpTo`, or a new `scrollTo`) after `setState(_isTransitioning = true)` but before the next frame builds the secondary list, the secondary list is never mounted. The awaited `Future.wait` then never completes, so the caller's `await scrollTo(...)` hangs. The stale `startAnimationCallback` also stays set and may fire on an unrelated later mount.
- **Fix direction:** keep the pending completers (or a single "pending start" handle) in state. In `_stopScroll`, if the start callback hasn't run yet, reset `startAnimationCallback = () {}` and complete the pending completers. Look at the re-entrancy `TODO` at ~line 627 at the same time.
- **Acceptance:** a test that calls `scrollTo(index: far)` and then, before pumping, cancels with `jumpTo` or a pointer-down. The returned future must complete after `pumpAndSettle`.

### 3. `jumpTo` reports a fake offset delta — NEEDS OWNER DECISION
**Status:** done in agent/list-state-followups — owner approved: reporting is suppressed during `_jumpTo`'s internal `jumpTo(0)` in both `recordProgrammaticScrolls` modes (`previousOffset` is still re-baselined). Patch applied and removed, regression test unskipped, changelog entry added.
- **File:** `lib/src/scrollable_positioned_list.dart`, `_jumpTo`
- **Problem:** `_jumpTo` calls `primary.scrollController.jumpTo(0)` to re-anchor the list. The offset listener reports this as a scroll of `-previousOffset` even though nothing moved visually. It's reported even when `recordProgrammaticScrolls` is `false`, because `_isTransitioning` is false at that point.
- **Fix direction:** set `previousOffset = 0` before the internal `jumpTo(0)`, or suppress reporting during it. Decide with the owner whether a `jumpTo` should report anything.
- **Acceptance:** with `recordProgrammaticScrolls: false`, `jumpTo` emits no delta. Existing offset tests pass.

### 4. Long-scroll direction uses a stale target — verify before fixing
**Status:** done in agent/list-state — reproduced (anchor 50, drag to 200, `scrollTo(100)` moved the visible list to 204); direction now comes from the lowest visible index, falling back to `primary.target`.
- **File:** `lib/src/scrollable_positioned_list.dart`, `_startScroll`: `final direction = index > primary.target ? 1 : -1;`
- **Suspected problem:** `primary.target` is the item the list was last anchored to, not what's on screen. Say the user `jumpTo(50)`, then drags manually to item 200, then calls `scrollTo(100)`. The direction is computed as forward, so the transition animates the wrong way. It still ends at the right place.
- **Fix direction:** derive the direction from the current visible positions, for example the lowest visible `index` in `primary.itemPositionsNotifier.itemPositions.value`. Fall back to `primary.target` if that's empty.
- **Acceptance:** first write a test showing that intermediate positions move away from the target. If you can't reproduce it, drop the task and report back.

### 5. Element registry keeps stale entries after reparenting
**Status:** done in agent/list-state-followups — reproduced at unit level (a `GlobalKey` subtree moved between two `RegistryWidget`s stayed in the old registry); `_register` now removes the element from its previous registry, and `_registryWidgetState` is nullable. Not reachable through the public API (each item's `RegisteredElementWidget` has a `ValueKey`, and nested lists have their own registry), so this is defensive.
- **File:** `lib/src/element_registry.dart`, `_RegisteredElement._register` / `didChangeDependencies`
- **Problem:** if a registered element moves under a different `RegistryWidget` (GlobalKey reparenting), `_register` adds it to the new registry but never removes it from the old one. The old list then reports positions for an item it no longer contains.
- **Fix:** in `_register`, if `_registryWidgetState` is already set and differs from the new one, remove `this` from the old set first. Make `_registryWidgetState` nullable instead of `late`.
- **Acceptance:** this is unit-level. The rare scenario needs a test using a `GlobalKey`-keyed item moved between two lists. Keep the fix minimal.

### 6. Calls on an unattached controller give unhelpful errors
**Status:** done in agent/list-state — added "is not attached to a ScrollablePositionedList" asserts to `ItemScrollController.jumpTo` and `ScrollOffsetController.animateScroll` (debug-only).
- **File:** `lib/src/scrollable_positioned_list.dart`, `ItemScrollController.jumpTo` and `ScrollOffsetController.animateScroll`
- **Problem:** both dereference `_scrollableListState!` with no assert. A caller who forgot to attach the controller gets a bare null-check error. `scrollTo` already has an assert.
- **Fix:** add `assert(_scrollableListState != null, '... is not attached to a ScrollablePositionedList')` to both. Debug-only, so there's no behaviour change in release.

### 7. Add a layout-cycle guard to the shrink-wrap viewport
**Status:** done in agent/list-state-followups — `_maxLayoutCycles = 10` cap and the debug `FlutterError` mirrored from `viewport.dart`; `effectiveExtent` is now computed after every attempt so it stays assigned if the cap ends the loop in release. Regression test uses a sliver that requests 20 corrections (no error before the fix).
- **File:** `lib/src/wrapping.dart:199-230`, `CustomRenderShrinkWrappingViewport.performLayout`
- **Problem:** the `do { ... } while (true)` loop has no cycle cap. `UnboundedRenderViewport` (`viewport.dart:150-194`) caps at `_maxLayoutCycles = 10` and throws a descriptive error in debug. If corrections keep happening, shrink-wrap mode hangs forever instead.
- **Fix:** mirror the `_maxLayoutCycles` counter and the debug `FlutterError` from `viewport.dart`. Leave the normal path unchanged.

## Performance

### 8. Don't notify position listeners when nothing changed
**Status:** done in agent/list-state — both the internal (`PositionedList`) and user-facing (`_updatePositions`) assignments are skipped when `listEquals` says nothing changed; `_stopScroll` now calls `_updatePositions()` after a swap, since the new primary's notifier may not fire again.
- **Files:** `lib/src/positioned_list.dart` (end of the post-frame callback in `_schedulePositionNotificationUpdate`) and `lib/src/scrollable_positioned_list.dart` (`_updatePositions`)
- **Problem:** every update assigns a new list to the `ValueNotifier`, so listeners always fire. Updates are scheduled on every `didUpdateWidget`, meaning every parent rebuild, even when no item moved. User widgets listening to `itemPositions` rebuild for nothing.
- **Fix:** before assigning, compare with the current value element by element (`ItemPosition` already implements `==`/`hashCode`, and `listEquals` from `foundation` works once both are lists). Skip the assignment if they're equal. Watch for the internal notifier feeding `_updatePositions`: that must still run whenever primary and secondary swap, so keep a test around the swap.
- **Acceptance:** a test where the parent rebuilds with identical props and the user's `itemPositions` listener isn't called. All existing position tests pass.

### 9. Skip redundant `_updatePositions` work for the hidden secondary list
**Status:** done in agent/list-state — one position listener per `_ListDisplayDetails` that only calls `_updatePositions` when its list is the current primary (128 → ≤ 77 updates over a 76-frame transition); the post-swap explicit call was added in task 8.
- **File:** `lib/src/scrollable_positioned_list.dart`: `_updatePositions` listens to both the primary and secondary internal notifiers.
- **Problem:** while transitioning, every secondary-list frame re-filters the primary's positions, rewrites `PageStorage` and re-notifies the user, even though primary positions didn't change in that callback.
- **Fix direction:** register separate listeners per `_ListDisplayDetails`, as was done for scroll controllers in `598e545`. Only recompute when the source notifier belongs to the current `primary`. After the swap in `_stopScroll`, call `_updatePositions()` once explicitly so the user immediately sees the new primary's positions.
- **Low priority.** Do it after task 8, and only if it stays simple.

### 10. Remove dead state in the shrink-wrap viewport
**Status:** done in agent/list-state-followups — removed `lastMainAxisExtent` and `growSize` (no references in `lib/`, `test/` or `example/`; `wrapping.dart` isn't exported).
- **File:** `lib/src/wrapping.dart`: `lastMainAxisExtent` (line 136) is never read. `growSize` (line 809, written at line 342) is written but never read anywhere in `lib/`.
- **Fix:** delete both. A pure cleanup; also check `test/` and `example/` for references first.

## Found while doing tasks 2–9 (not started)

Line numbers below are for `e72c4d4` (tip of `agent/list-state`), not `598e545`. Tasks 11 and 12 edit `lib/src/scrollable_positioned_list.dart`, so do them after the group above or with the same agent.

### 11. `scrollTo` future hangs if the list is disposed before the transition starts
**Status:** done in agent/list-state-followups — `dispose` now calls `_cancelPendingStart()`, so a long scroll's pending futures complete when the list is removed before the secondary list mounts.
- **File:** `lib/src/scrollable_positioned_list.dart`, `dispose` (~line 409)
- **Problem:** task 2 completes a long scroll's pending futures in `_stopScroll`, but `dispose` doesn't. If the list is removed after `scrollTo(index: far)` and before the secondary list mounts, `await scrollTo(...)` never completes.
- **Fix direction:** call `_cancelPendingStart()` in `dispose`.
- **Acceptance:** a test that calls `scrollTo(index: far)`, then replaces the list with an empty widget before pumping. The returned future must complete.

### 12. Long-scroll start callback has no `mounted` guard
**Status:** done in agent/list-state-followups — reproduced on `1344f20` (list removed by a second layout pass in the frame the secondary list mounts: the post-frame callback threw "This widget has been unmounted" from `AnimationController(vsync: this)` and the future hung); already fixed by task 11, since `dispose` completes `startCompleter` and the callback's existing `isCompleted` check returns early. Regression test added; no further `lib/` change.
- **File:** `lib/src/scrollable_positioned_list.dart`, `startAnimationCallback`'s post-frame callback (~line 623)
- **Problem:** the post-frame callback creates `AnimationController(vsync: this)` and drives both scroll controllers without checking `mounted`. If the list is disposed between the secondary list mounting and that post-frame callback, it runs on a disposed state.
- **Fix direction:** return early if `!mounted`, after completing the pending completers (see task 11). Verify first: this window may be impossible to hit in practice, since mount and post-frame happen in the same frame. If you can't reproduce it, mark it "not reproduced".

### 13. Position comparison is order-sensitive (low priority)
**Status:** done in agent/list-state-followups — reproduced (drag away and back so items re-register out of order, then `jumpTo` the item already at the top: same positions, reversed order, listener fired once); both comparisons now use `samePositions` (`listEquals` fast path, then length + `setEquals`). Assigned lists are never sorted; when an update is skipped, listeners keep the previous value and its order.
- **Files:** `lib/src/positioned_list.dart` (~line 385) and `lib/src/scrollable_positioned_list.dart` `_updatePositions` (~line 764)
- **Problem:** task 8 compares positions with `listEquals`, but they're collected by iterating a `Set<Element>` registry. If the same positions come back in a different order (for example after elements re-register), listeners are notified anyway. Harmless, just not fully deduplicated.
- **Fix direction:** only if it stays cheap, for example sort by `index` before comparing, or compare as sets. Don't change the order users see unless the owner approves.

### 14. Add `.gitattributes` for line endings
**Status:** done in agent/list-state-followups — added `* text=auto eol=lf` plus `binary` for image/font/jar types; `git add --renormalize .` staged nothing else (the index was already all LF; the only binaries, 5 launcher PNGs, are untouched).
- **File:** new `.gitattributes` at the repo root
- **Problem:** with no `.gitattributes`, commits on Windows warn "LF will be replaced by CRLF", and line endings depend on each contributor's `core.autocrlf`.
- **Fix:** add `* text=auto eol=lf` (plus `binary` entries for any binary assets), then run `git add --renormalize .` and check that the diff is empty or endings-only. Commit as `chore:`.

### 15. Re-entrant `scrollTo` runs on a disposed list — verify before fixing
**Status:** done in agent/list-state-followups — reproduced (`_startScroll` hit `'_positions.isNotEmpty'` on the disposed controller and the future hung); the deferred callback now completes `scrollCompleter` and returns when `!mounted`.
- **File:** `lib/src/scrollable_positioned_list.dart`, `_scrollTo`, the `_isTransitioning` branch (~line 557 at `ef8d53e`)
- **Suspected problem:** a `scrollTo` issued while a transition is running cancels it and calls `_startScroll` from a post-frame callback with no `mounted` check. If the list is disposed before that callback runs, `_startScroll` touches the disposed controllers and `scrollCompleter` never completes, so `await scrollTo(...)` hangs.
- **Fix direction:** in that callback, if `!mounted`, complete `scrollCompleter` and return. Write a reproducing test first; mark "not reproduced" if it can't be hit.

---

## Investigated and rejected (don't pick up)

- **"Shrink-wrap in an unbounded parent builds every item."** It does (500 of 500 in a `SingleChildScrollView`), but so does Flutter's own `ListView(shrinkWrap: true)` in the same setup. That's inherent to shrink-wrapping, not a bug in this package.
