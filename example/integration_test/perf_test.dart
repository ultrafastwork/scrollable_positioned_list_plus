// Profile-mode frame-timing harness for ScrollablePositionedList.
//
// Run on a real device from `example/`:
//
//   flutter drive --profile --driver=test_driver/perf_driver.dart \
//     --target=integration_test/perf_test.dart -d <device>
//
// Each scenario is wrapped in `binding.watchPerformance`, which records the
// engine's FrameTimings (build and raster time per frame, missed frames). The
// driver writes one JSON summary per scenario to `example/build/perf/`.
//
// This file is not under `test/`, so `flutter test` does not pick it up.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:scrollable_positioned_list_plus/scrollable_positioned_list_plus.dart';

const _itemCount = 10000;

/// How many drag/fling gestures each drag scenario performs.
const _dragRounds = 6;

/// How many `scrollTo` calls each scrollTo scenario performs.
const _scrollToRounds = 10;

const _scrollToDuration = Duration(milliseconds: 600);

final _listFinder = find.byType(ScrollablePositionedList);

/// The `ListTile`s below are 72 px tall anyway, so passing this as
/// `itemExtent` changes how the list is laid out and scrolled, not what it
/// shows.
const _fixedItemExtent = 72.0;

class _PerfList extends StatelessWidget {
  const _PerfList({
    required this.separated,
    required this.fixed,
    required this.itemScrollController,
    this.itemPositionsListener,
  });

  final bool separated;

  /// Whether to pass `itemExtent` (and `separatorExtent`).
  final bool fixed;
  final ItemScrollController itemScrollController;
  final ItemPositionsListener? itemPositionsListener;

  Widget _item(BuildContext context, int index) => ListTile(
    key: ValueKey<int>(index),
    leading: CircleAvatar(child: Text('${index % 100}')),
    title: Text('Item $index'),
    subtitle: Text('Subtitle for item $index'),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: separated
              ? ScrollablePositionedList.separated(
                  itemCount: _itemCount,
                  itemBuilder: _item,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemScrollController: itemScrollController,
                  itemPositionsListener: itemPositionsListener,
                  itemExtent: fixed ? _fixedItemExtent : null,
                  separatorExtent: fixed ? 1 : null,
                )
              : ScrollablePositionedList.builder(
                  itemCount: _itemCount,
                  itemBuilder: _item,
                  itemScrollController: itemScrollController,
                  itemPositionsListener: itemPositionsListener,
                  itemExtent: fixed ? _fixedItemExtent : null,
                ),
        ),
      ),
    );
  }
}

/// Pumps a fresh list and returns its scroll controller.
Future<ItemScrollController> _pumpList(
  WidgetTester tester, {
  required bool separated,
  required bool withListener,
  bool fixed = false,
}) async {
  final controller = ItemScrollController();
  ItemPositionsListener? listener;
  if (withListener) {
    listener = ItemPositionsListener.create();
    // A cheap consumer, like a "first visible item" label would be.
    final firstVisible = ValueNotifier<int>(0);
    addTearDown(firstVisible.dispose);
    listener.itemPositions.addListener(() {
      var min = -1;
      for (final position in listener!.itemPositions.value) {
        if (position.itemTrailingEdge > 0 &&
            (min < 0 || position.index < min)) {
          min = position.index;
        }
      }
      if (min >= 0) firstVisible.value = min;
    });
  }
  await tester.pumpWidget(
    _PerfList(
      separated: separated,
      fixed: fixed,
      itemScrollController: controller,
      itemPositionsListener: listener,
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

/// Slow drags followed by flings, alternating direction so the list stays
/// well inside its 10,000 items.
Future<void> _dragAndFling(WidgetTester tester, {required int rounds}) async {
  for (var i = 0; i < rounds; i++) {
    final sign = i.isEven ? -1.0 : 1.0;
    await tester.timedDrag(
      _listFinder,
      Offset(0, sign * 1500),
      const Duration(milliseconds: 1500),
    );
    await tester.pumpAndSettle();
    await tester.fling(_listFinder, Offset(0, sign * 600), 4000);
    await tester.pumpAndSettle();
  }
}

/// Animates [rounds] times between [from] and [to].
Future<void> _scrollBetween(
  ItemScrollController controller,
  WidgetTester tester, {
  required int from,
  required int to,
  required int rounds,
}) async {
  for (var i = 0; i < rounds; i++) {
    await controller.scrollTo(
      index: i.isEven ? to : from,
      duration: _scrollToDuration,
    );
    await tester.pumpAndSettle();
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Let the engine drive frames at the display's vsync, as in a real app.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  for (final separated in [false, true]) {
    final suffix = separated ? '_separated' : '';

    testWidgets('drag with listener$suffix', (tester) async {
      await _pumpList(tester, separated: separated, withListener: true);
      await _dragAndFling(tester, rounds: 1); // warm-up
      await binding.watchPerformance(
        () => _dragAndFling(tester, rounds: _dragRounds),
        reportKey: 'drag_with_listener$suffix',
      );
    });

    testWidgets('long scrollTo$suffix', (tester) async {
      final controller = await _pumpList(
        tester,
        separated: separated,
        withListener: true,
      );
      await _scrollBetween(controller, tester, from: 100, to: 5000, rounds: 2);
      await binding.watchPerformance(
        () => _scrollBetween(
          controller,
          tester,
          from: 100,
          to: 5000,
          rounds: _scrollToRounds,
        ),
        reportKey: 'long_scroll_to$suffix',
      );
    });
  }

  testWidgets('drag without listener', (tester) async {
    await _pumpList(tester, separated: false, withListener: false);
    await _dragAndFling(tester, rounds: 1); // warm-up
    await binding.watchPerformance(
      () => _dragAndFling(tester, rounds: _dragRounds),
      reportKey: 'drag_without_listener',
    );
  });

  testWidgets('short scrollTo', (tester) async {
    final controller = await _pumpList(
      tester,
      separated: false,
      withListener: true,
    );
    // Items are ~72 px tall, so 12 items is about one screen: close enough
    // that scrollTo animates directly instead of crossfading.
    await _scrollBetween(controller, tester, from: 100, to: 112, rounds: 2);
    await binding.watchPerformance(
      () => _scrollBetween(
        controller,
        tester,
        from: 100,
        to: 112,
        rounds: _scrollToRounds,
      ),
      reportKey: 'short_scroll_to',
    );
  });

  // About 3.5 screens: too far for the default path's cache, so it crossfades.
  testWidgets('medium scrollTo', (tester) async {
    final controller = await _pumpList(
      tester,
      separated: false,
      withListener: true,
    );
    await _scrollBetween(controller, tester, from: 100, to: 140, rounds: 2);
    await binding.watchPerformance(
      () => _scrollBetween(
        controller,
        tester,
        from: 100,
        to: 140,
        rounds: _scrollToRounds,
      ),
      reportKey: 'medium_scroll_to',
    );
  });

  // Fixed-extent mode (task 20). `scrollTo` animates directly up to about 10
  // screens and crossfades beyond that.
  testWidgets('fixed drag with listener', (tester) async {
    await _pumpList(tester, separated: false, withListener: true, fixed: true);
    await _dragAndFling(tester, rounds: 1); // warm-up
    await binding.watchPerformance(
      () => _dragAndFling(tester, rounds: _dragRounds),
      reportKey: 'fixed_drag_with_listener',
    );
  });

  for (final (name, to, separated) in [
    ('fixed_short_scroll_to', 112, false),
    ('fixed_medium_scroll_to', 140, false),
    ('fixed_medium_scroll_to_separated', 140, true),
    ('fixed_9_screens_scroll_to', 200, false), // just under the 10-screen cap
    ('fixed_long_scroll_to', 5000, false),
  ]) {
    testWidgets(name, (tester) async {
      final controller = await _pumpList(
        tester,
        separated: separated,
        withListener: true,
        fixed: true,
      );
      await _scrollBetween(controller, tester, from: 100, to: to, rounds: 2);
      await binding.watchPerformance(
        () => _scrollBetween(
          controller,
          tester,
          from: 100,
          to: to,
          rounds: _scrollToRounds,
        ),
        reportKey: name,
      );
    });
  }
}
