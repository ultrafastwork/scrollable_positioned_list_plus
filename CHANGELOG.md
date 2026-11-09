# Unreleased
* `ItemPositionsListener.itemPositions` now reports positions sorted by index. The order used to depend on the order items were built in.
* `ScrollOffsetListener.changes` is now a broadcast stream. It can have several listeners, and deltas emitted while nobody listens are dropped instead of being buffered in memory without limit (and replayed to a late listener).
* `ItemScrollController.jumpTo` no longer reports a scroll offset change to `ScrollOffsetListener`. It used to report `-previousOffset` (even with `recordProgrammaticScrolls: false`), although nothing moved on screen.
* Fix: when `scrollTo` (or `jumpTo`) is called several times during a long scroll, the latest call now wins. Previously an earlier `scrollTo` could start after a later one and cancel it, so the list stopped at the wrong item ([google/flutter.widgets#171](https://github.com/google/flutter.widgets/issues/171)).
* Fix: `jumpTo` after a long manual scroll through items of different heights now places the item where requested. Previously the list could land a few items past the target ([google/flutter.widgets#144](https://github.com/google/flutter.widgets/issues/144)).
* Fix: the future returned by `scrollTo` now always completes. It used to hang forever if the scroll was canceled (by `jumpTo`, another `scrollTo` or a tap) before its animation started, or if the list was removed from the tree first.
* Fix: a long `scrollTo` animates in the right direction after the user has scrolled by hand. The direction used to come from the last item jumped or scrolled to, not from what was on screen.
* Fix: a shrink-wrapped list whose content keeps changing size during layout now stops after 10 layout passes (with a descriptive error in debug mode) instead of hanging.
* `ItemPositionsListener.itemPositions` listeners are no longer called when a rebuild leaves every position unchanged.
* `ItemScrollController.jumpTo` and `ScrollOffsetController.animateScroll` now fail with a descriptive assert when the controller isn't attached to a list.
* Migrate off deprecated Flutter APIs: `cacheExtent`/`cacheExtentStyle` → `ScrollCacheExtent`, `Matrix4.translate` → `translateByDouble`.
* Remove the `collection` dependency and the discontinued `pedantic` dev dependency.
* Adopt `flutter_lints` and modern Dart 3 idioms (super parameters, switch expressions, records).
* Enable stricter analysis (strict casts, inference and raw types, plus extra lint rules) and add a scroll micro-benchmark under `benchmark/`.
* Example: migrate deprecated APIs and fix duplicate button keys.

# 0.4.0
* Forked from `scrollable_positioned_list` 0.3.8+1 (google/flutter.widgets) and renamed to `scrollable_positioned_list_plus`.
* Main library is now `package:scrollable_positioned_list_plus/scrollable_positioned_list_plus.dart`.

# 0.3.8+1
* Migrate tests off deprecated APIs.
* Bump min Flutter version to 3.1.0.

# 0.3.8
* Add ScrollOffsetController to allow pixel-based changes in offset.
* Bump min sdk version to 2.15.0

# 0.3.7
* Add ScrollOffsetListener to allow listening to changes in scroll offset.

# 0.3.6
* Fix cache extents for horizontal lists
* scrollTo future doesn't complete until scrolling is done.

# 0.3.5
* Fix extraneous animation controller declaration in 0.3.4.

# 0.3.4
* Disposed the animation controller when disposing the scrollable list.

# 0.3.3
* Fix potential crash when reading from RenderBox.size.

# 0.3.2
* Re-apply Flutter framework bindings' null safety calls but set SDK
  constraints correctly to 2.12.0 instead.

# 0.3.1
* Reverts change from 0.3.0 where the Flutter version constraint should have
  been set to 2.12.0 instead of 2.10.5.

# 0.3.0
  * Move to Flutter version 2.10.5 and update dependencies' null safety calls.

# 0.2.3
  * Support shrink wrap.
# 0.2.2
  * Move dependencies from pre-release versions to released versions.

# 0.2.1
  * Fix crash on NaN or infinite offset.

# 0.2.0-nullsafety.0
  * Update to null safety.

# 0.1.10
  * Update the home page URL to fix
    [issue #190](https://github.com/google/flutter.widgets/issues/190).
  * Miscellaneous tweaks to the example.
  * Added documentation to address
    [issue #96](https://github.com/google/flutter.widgets/issues/96).
  * Miscellaneous other cleanup.
  * Restructured `_ScrollablePositionedListState` to try to simplify logic.
  * Fixed an issue with `ItemScrollController.scrollTo` where it could scroll to
    the wrong item if a non-zero `alignment` was specified and if the list was
    manually scrolled by dragging.

# 0.1.9
  * Fixed the example in `README.md`.  Fixes
    [issue #191](https://github.com/google/flutter.widgets/issues/191).
  * Made the example runnable with `flutter run`.  Fixes
    [issue #211](https://github.com/google/flutter.widgets/issues/211).
  * Updates to computation of semantic clip.
  * Smoother transition between views on long scrolls.
  * New controls over transition between views on long scrolls.

# 0.1.8
  * Set updateScheduled to false when short circuiting due to empty list.
    To fix https://github.com/google/flutter.widgets/issues/182.

# 0.1.7
  * Apply viewport dimensions in UnboundedRenderedViewport.performResize.
    To work around change in https://github.com/flutter/flutter/pull/61973
    causing breakage

# 0.1.6
  * Change to do local scroll (without a fade) whenever target item is found
    within the cache.
  * Added sdk constraints to the example.
  * Moved `itemScrollControllerDetachment` to
    `_ScrollablePositionedListState.deactivate`.

# 0.1.5

  * Added minCacheExtent to ScrollablePositionedList
  * Fixes the issue when item count updated from zero to one and `index` in
    `itemBuilder` becomes `-1`.  Fixes
    [issue #104](https://github.com/google/flutter.widgets/issues/104).

# 0.1.4

  *  itemBuilders should not be called with indices > itemCount - 1.  Fixes
     [issue #42](https://github.com/google/flutter.widgets/issues/42) and
     [issue #77](https://github.com/google/flutter.widgets/issues/77).

# 0.1.3

  * Don't build items when `itemCount` is 0. Fixes
    [issue #78](https://github.com/google/flutter.widgets/issues/78).

  * Fix typos in `README.md`.

# 0.1.2

  * Store scroll state in page storage to fix
    [issue #43](https://github.com/google/flutter.widgets/issues/43).

# 0.1.1

  * Fix padding for horizontal lists.

  * Add `ScrollablePositionedList.separated` constructor to complete
    [issue #34](https://github.com/google/flutter.widgets/issues/34).

  * Add `isAttached` method to `ItemScrollController`.

# 0.1.0

  * Properly bound `ScrollablePositionedList` to fix
    [issue #23](https://github.com/google/flutter.widgets/issues/23).

  * Allow `ScrollablePositionedList` alignment outside `[0..1]` to fix
    [issue #31](https://github.com/google/flutter.widgets/issues/31).

  * Moved `ScrollablePositionedList` example into `example` subdirectory.

# 0.0.1

* Added `ScrollablePositionedList`.
