# 8. Don't notify position listeners when nothing changed

**Area:** performance · **Line numbers:** `598e545`

**Status:** done in agent/list-state — both the internal (`PositionedList`) and user-facing (`_updatePositions`) assignments are skipped when `listEquals` says nothing changed; `_stopScroll` now calls `_updatePositions()` after a swap, since the new primary's notifier may not fire again.

- **Files:** `lib/src/positioned_list.dart` (end of the post-frame callback in `_schedulePositionNotificationUpdate`) and `lib/src/scrollable_positioned_list.dart` (`_updatePositions`)
- **Problem:** every update assigns a new list to the `ValueNotifier`, so listeners always fire. Updates are scheduled on every `didUpdateWidget`, meaning every parent rebuild, even when no item moved. User widgets listening to `itemPositions` rebuild for nothing.
- **Fix:** before assigning, compare with the current value element by element (`ItemPosition` already implements `==`/`hashCode`, and `listEquals` from `foundation` works once both are lists). Skip the assignment if they're equal. Watch for the internal notifier feeding `_updatePositions`: that must still run whenever primary and secondary swap, so keep a test around the swap.
- **Acceptance:** a test where the parent rebuilds with identical props and the user's `itemPositions` listener isn't called. All existing position tests pass.
