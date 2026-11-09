# 16. An older deferred `scrollTo` cancels a newer one (google/flutter.widgets#171)

**Area:** correctness (previously skipped upstream test, now unskipped)

**Status:** done on `main`. `scrollTo(100); scrollTo(200); scrollTo(300)` ended on 200: the second call cancels the transition (clearing `_isTransitioning`) and defers its start, so the third started immediately and was then canceled by the second's post-frame callback. Same for `jumpTo` after a deferred `scrollTo`. Every `_jumpTo`/`_scrollTo` now takes a `_scrollRequestId`; a `scrollTo` also defers while another deferred scroll is pending (`_deferredScrollId`), and a deferred callback that isn't the latest request completes its future and returns. Tests: the upstream test, plus "Task 16" in `test/list_state_regression_test.dart`.

- **File:** `lib/src/scrollable_positioned_list.dart`, `_scrollTo` and `_jumpTo`
