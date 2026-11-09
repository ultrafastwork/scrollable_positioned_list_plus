# 12. Long-scroll start callback has no `mounted` guard

**Area:** correctness · **Line numbers:** `e72c4d4`

**Status:** done in agent/list-state-followups — reproduced on `1344f20` (list removed by a second layout pass in the frame the secondary list mounts: the post-frame callback threw "This widget has been unmounted" from `AnimationController(vsync: this)` and the future hung); already fixed by task 11, since `dispose` completes `startCompleter` and the callback's existing `isCompleted` check returns early. Regression test added; no further `lib/` change.

- **File:** `lib/src/scrollable_positioned_list.dart`, `startAnimationCallback`'s post-frame callback (~line 623)
- **Problem:** the post-frame callback creates `AnimationController(vsync: this)` and drives both scroll controllers without checking `mounted`. If the list is disposed between the secondary list mounting and that post-frame callback, it runs on a disposed state.
- **Fix direction:** return early if `!mounted`, after completing the pending completers (see task 11). Verify first: this window may be impossible to hit in practice, since mount and post-frame happen in the same frame. If you can't reproduce it, mark it "not reproduced".
