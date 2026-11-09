# scrollable_positioned_list_plus

A maintained fork of
[`scrollable_positioned_list`](https://pub.dev/packages/scrollable_positioned_list).

A flutter list that allows scrolling to a specific item in the list.

Also allows determining what items are currently visible.

## Credits

This package is a fork of
[`scrollable_positioned_list`](https://pub.dev/packages/scrollable_positioned_list),
originally created by Google and the
[flutter.widgets](https://github.com/google/flutter.widgets/tree/master/packages/scrollable_positioned_list)
contributors. All credit for the original design and implementation goes to
them.

The original package has not been updated for a long time, so this fork exists
to keep it maintained (bug fixes, compatibility with new Flutter releases, and
small improvements).

This fork is distributed under the same BSD-3-Clause license as the original.
See [LICENSE](LICENSE).

## Migrating from `scrollable_positioned_list`

The API is the same. Replace the dependency in your `pubspec.yaml`:

```yaml
dependencies:
  scrollable_positioned_list_plus: ^0.4.0
```

and update your imports:

```dart
// Before
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

// After
import 'package:scrollable_positioned_list_plus/scrollable_positioned_list_plus.dart';
```

## Usage

A `ScrollablePositionedList` works much like the builder version of `ListView`
except that the list can be scrolled or jumped to a specific item.

### Example

A `ScrollablePositionedList` can be created with:

```dart
final ItemScrollController itemScrollController = ItemScrollController();
final ScrollOffsetController scrollOffsetController = ScrollOffsetController();
final ItemPositionsListener itemPositionsListener = ItemPositionsListener.create();
final ScrollOffsetListener scrollOffsetListener = ScrollOffsetListener.create();

ScrollablePositionedList.builder(
  itemCount: 500,
  itemBuilder: (context, index) => Text('Item $index'),
  itemScrollController: itemScrollController,
  scrollOffsetController: scrollOffsetController,
  itemPositionsListener: itemPositionsListener,
  scrollOffsetListener: scrollOffsetListener,
);
```

One then can scroll to a particular item with:

```dart
itemScrollController.scrollTo(
  index: 150,
  duration: Duration(seconds: 2),
  curve: Curves.easeInOutCubic);
```

or jump to a particular item with:

```dart
itemScrollController.jumpTo(index: 150);
```

One can monitor what items are visible on screen with:

```dart
itemPositionsListener.itemPositions.addListener(() => ...);
```

### Experimental APIs (subject to bugs and changes)

Changes in scroll position can be monitored with:

```dart
scrollOffsetListener.changes.listen((event) => ...)
```

see `ScrollSum` in [this test](test/scroll_offset_listener_test.dart) for an example of how the current offset can be
calculated from the stream of scroll change deltas.  This feature is new and experimental.

Changes in scroll position in pixels, relative to the current scroll position, can be made with:

```dart
scrollOffsetController.animateScroll(offset: 100, duration: Duration(seconds: 1));
```

A full example can be found in the [example](example) folder.

## Contributing

Issues and pull requests are welcome at
[github.com/ultrafastwork/scrollable_positioned_list_plus](https://github.com/ultrafastwork/scrollable_positioned_list_plus).
