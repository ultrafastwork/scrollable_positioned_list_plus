# 1. `ScrollOffsetListener` buffers events without limit — NEEDS OWNER DECISION

**Area:** correctness · **Line numbers:** `598e545`

**Status:** done in agent/list-state-followups — owner approved; `StreamController<double>.broadcast()`, doc comment on `changes` updated, changelog entry added. Regression test: two listeners both receive deltas (the second `listen` threw "Stream has already been listened to" before).

- **File:** `lib/src/scroll_offset_notifier.dart:12`
- **Problem:** `StreamController<double>()` creates a single-subscription stream. If a `ScrollOffsetListener` is passed to the list but nobody calls `changes.listen` (or listens late), every scroll delta is buffered in memory forever. A second `listen` throws.
- **Proposed fix:** `StreamController<double>.broadcast()`.
- **Behaviour change:** events emitted before anyone listens are dropped, not replayed, and multiple listeners become allowed. Get owner approval, then add a changelog entry.
- **Acceptance:** add a test that two listeners both receive deltas. Existing `test/scroll_offset_listener_test.dart` still passes.
