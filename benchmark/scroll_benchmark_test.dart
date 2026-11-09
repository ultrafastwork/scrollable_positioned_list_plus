// Micro-benchmark for ScrollablePositionedList.
//
// Lives outside `test/` so the regular `flutter test` run skips it. Run with:
//
//   flutter test benchmark/scroll_benchmark_test.dart
//
// Numbers come from the test binding (JIT, no rasterization), so they are only
// meaningful relative to each other: run before and after a change on the same
// machine. For real frame timings, profile the example app in profile mode.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollable_positioned_list_plus/scrollable_positioned_list_plus.dart';

const _itemCount = 10000;
const _itemExtent = 50.0;
const _frames = 600;
const _warmupFrames = 60;
const _frameDuration = Duration(milliseconds: 16);

Future<void> _pumpList(
  WidgetTester tester, {
  required ItemScrollController itemScrollController,
  required ItemPositionsListener? itemPositionsListener,
  bool separated = false,
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  Widget item(BuildContext context, int index) =>
      SizedBox(height: _itemExtent, child: Text('Item $index'));

  await tester.pumpWidget(
    MaterialApp(
      home: separated
          ? ScrollablePositionedList.separated(
              itemCount: _itemCount,
              itemBuilder: item,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemScrollController: itemScrollController,
              itemPositionsListener: itemPositionsListener,
            )
          : ScrollablePositionedList.builder(
              itemCount: _itemCount,
              itemBuilder: item,
              itemScrollController: itemScrollController,
              itemPositionsListener: itemPositionsListener,
            ),
    ),
  );
}

/// Drags the list by [delta] pixels per frame for [frames] frames and returns
/// the average wall-clock time per frame in microseconds.
Future<double> _dragFrames(
  WidgetTester tester, {
  required int frames,
  required double delta,
}) async {
  final gesture = await tester.startGesture(const Offset(200, 400));
  // Get past the touch slop so every following move scrolls.
  await gesture.moveBy(const Offset(0, -40));
  await tester.pump(_frameDuration);

  final stopwatch = Stopwatch()..start();
  for (var i = 0; i < frames; i++) {
    // Alternate direction every 200 frames so we stay inside the list.
    final sign = (i ~/ 200).isEven ? -1.0 : 1.0;
    await gesture.moveBy(Offset(0, sign * delta));
    await tester.pump(_frameDuration);
  }
  stopwatch.stop();
  await gesture.up();
  await tester.pumpAndSettle();
  return stopwatch.elapsedMicroseconds / frames;
}

void _report(String name, double microsPerFrame) {
  // ignore: avoid_print
  print('BENCH $name: ${microsPerFrame.toStringAsFixed(1)} us/frame');
}

void main() {
  for (final separated in [false, true]) {
    final label = separated ? 'separated' : 'builder';

    testWidgets('drag scroll ($label)', (tester) async {
      final positions = ItemPositionsListener.create();
      var notifications = 0;
      positions.itemPositions.addListener(() => notifications++);
      await _pumpList(
        tester,
        itemScrollController: ItemScrollController(),
        itemPositionsListener: positions,
        separated: separated,
      );

      await _dragFrames(tester, frames: _warmupFrames, delta: 7);
      final micros = await _dragFrames(tester, frames: _frames, delta: 7);
      _report('drag scroll ($label)', micros);
      expect(notifications, greaterThan(0));
    });

    testWidgets('drag scroll, no listener ($label)', (tester) async {
      await _pumpList(
        tester,
        itemScrollController: ItemScrollController(),
        itemPositionsListener: null,
        separated: separated,
      );

      await _dragFrames(tester, frames: _warmupFrames, delta: 7);
      final micros = await _dragFrames(tester, frames: _frames, delta: 7);
      _report('drag scroll, no listener ($label)', micros);
    });

    testWidgets('long scrollTo ($label)', (tester) async {
      final controller = ItemScrollController();
      await _pumpList(
        tester,
        itemScrollController: controller,
        itemPositionsListener: ItemPositionsListener.create(),
        separated: separated,
      );

      const duration = Duration(milliseconds: 500);
      const jumps = 20;
      final stopwatch = Stopwatch()..start();
      var frames = 0;
      for (var i = 0; i < jumps; i++) {
        final target = (i.isEven ? 5000 : 100) + i;
        final done = controller.scrollTo(index: target, duration: duration);
        while (tester.binding.hasScheduledFrame) {
          await tester.pump(_frameDuration);
          frames++;
        }
        await done;
      }
      stopwatch.stop();
      _report('long scrollTo ($label)', stopwatch.elapsedMicroseconds / frames);
    });
  }
}
