# scrollable_positioned_list_plus — performance & correctness tasks

Repo: https://github.com/ultrafastwork/scrollable_positioned_list_plus (branch `main`).
Flutter package; all source is in `lib/src/`, tests in `test/`.

This file is the index. Each task has its own file in this directory with the full details. When you finish a task, update the **Status** line in its file and the status column below.

## Ground rules for every task

- **Don't break existing behaviour.** On `a0ee16b`, `flutter test` gives 204 passed and 0 skipped. That must still hold after your change (plus any tests you add), and `flutter analyze` must report no issues. For tasks 1–10 the baseline was `598e545` (182 passed, 2 skipped).
- **Prove the bug first.** For a correctness task, add a regression test that fails before your fix and passes with it. Check this by stashing `lib/`, running the test, then restoring.
- **Prove the gain.** For a performance task, record before/after numbers in the task file, from [task 22](22-device-profiling-harness.md) if a device is available, otherwise from `flutter test benchmark/scroll_benchmark_test.dart` (relative numbers only). If there's no measurable gain, don't merge: record the numbers and close the task as "not worth it".
- **Ask before changing public behaviour.** If a task is marked **NEEDS OWNER DECISION**, don't change observable behaviour or add public API without the owner's approval. Implement it behind the approved option only, and add a changelog entry.
- **Keep commits small.** Make one commit per task (or per part, where a task has parts), and don't touch unrelated code.
- **Line numbers** are for the commit named at the top of each task file.

## Open tasks

Recommended order: **22 → 19 → 18 → 20 → 21.**

| # | Task | Area | Status |
|---|------|------|--------|
| 18 | [Shrink the default cache extent](18-default-cache-extent.md) — NEEDS OWNER DECISION | performance | not started |
| 19 | [Compute item positions only when needed, and more cheaply](19-lazy-position-computation.md) | performance | not started |
| 20 | [Fixed-extent mode (`itemExtent` / `prototypeItem`)](20-fixed-extent-mode.md) — NEEDS OWNER DECISION | performance, new API | not started |
| 21 | [Reduce the cost of the long-scroll crossfade](21-transition-cost.md) (low priority) | performance | not started |
| 22 | [Profile-mode performance harness on a real device](22-device-profiling-harness.md) | measurement | not started |

**File conflicts:**
- Tasks 18, 19, 20 and 21 all edit `lib/src/scrollable_positioned_list.dart`, and 19 and 20 also edit `lib/src/positioned_list.dart`. Give them to one agent or do them one after another.
- Task 22 only touches `example/`, so it can run in parallel with anything.

**Running the device harness (task 22):** from `example/`, run `flutter drive --profile --driver=test_driver/perf_driver.dart --target=integration_test/perf_test.dart -d <device>`. Results are written to `example/build/perf/`.

## Done

### Correctness

| # | Task | Status |
|---|------|--------|
| 1 | [`ScrollOffsetListener` buffers events without limit](01-scroll-offset-listener-buffering.md) | done |
| 2 | [`scrollTo` future can never complete](02-scroll-to-future-never-completes.md) | done |
| 3 | [`jumpTo` reports a fake offset delta](03-jump-to-fake-offset-delta.md) | done |
| 4 | [Long-scroll direction uses a stale target](04-long-scroll-stale-direction.md) | done |
| 5 | [Element registry keeps stale entries after reparenting](05-registry-stale-entries-after-reparenting.md) | done |
| 6 | [Calls on an unattached controller give unhelpful errors](06-unattached-controller-asserts.md) | done |
| 7 | [Add a layout-cycle guard to the shrink-wrap viewport](07-shrink-wrap-layout-cycle-guard.md) | done |
| 11 | [`scrollTo` future hangs if the list is disposed before the transition starts](11-scroll-to-hangs-on-dispose.md) | done |
| 12 | [Long-scroll start callback has no `mounted` guard](12-long-scroll-start-mounted-guard.md) | done (fixed by 11) |
| 15 | [Re-entrant `scrollTo` runs on a disposed list](15-reentrant-scroll-to-after-dispose.md) | done |
| 16 | [An older deferred `scrollTo` cancels a newer one (google/flutter.widgets#171)](16-older-deferred-scroll-to-wins.md) | done |
| 17 | [`jumpTo` lands past the target after a manual scroll with variable heights (google/flutter.widgets#144)](17-jump-to-overshoots-variable-heights.md) | done |

### Performance

| # | Task | Status |
|---|------|--------|
| 8 | [Don't notify position listeners when nothing changed](08-skip-unchanged-position-notifications.md) | done |
| 9 | [Skip redundant `_updatePositions` work for the hidden secondary list](09-skip-secondary-position-updates.md) | done |
| 10 | [Remove dead state in the shrink-wrap viewport](10-shrink-wrap-dead-state.md) | done |
| 13 | [Position comparison is order-sensitive](13-order-sensitive-position-comparison.md) | done, superseded by `22d1e85` |

### Tooling

| # | Task | Status |
|---|------|--------|
| 14 | [Add `.gitattributes` for line endings](14-gitattributes-line-endings.md) | done |

### Already fixed in 598e545 (don't redo)

The scroll-offset listener now survives the list swap. `ScrollOffsetController` is re-attached in `didUpdateWidget`. Index is clamped. `PageStorage.maybeOf` is used. The post-frame callback has `mounted`/`hasClients` guards. Controllers and notifiers are disposed. The registry `updateShouldNotify` no longer always returns `true`. Positions are materialized once, the `ReverseAnimation` is cached, and redundant `setState` calls are gone.

## Investigated and rejected (don't pick up)

- **"Shrink-wrap in an unbounded parent builds every item."** It does (500 of 500 in a `SingleChildScrollView`), but so does Flutter's own `ListView(shrinkWrap: true)` in the same setup. That's inherent to shrink-wrapping, not a bug in this package.
