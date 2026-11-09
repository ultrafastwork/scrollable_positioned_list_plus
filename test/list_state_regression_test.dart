// Copyright 2026 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Regression tests for ScrollablePositionedList state handling.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollable_positioned_list_plus/scrollable_positioned_list_plus.dart';

const screenHeight = 400.0;
const screenWidth = 400.0;
const itemHeight = screenHeight / 10.0;
const defaultItemCount = 500;
const scrollDuration = Duration(seconds: 1);

void main() {
  Future<void> setUpWidgetTest(
    WidgetTester tester, {
    ItemScrollController? itemScrollController,
    ItemPositionsListener? itemPositionsListener,
    ScrollOffsetListener? scrollOffsetListener,
    int initialIndex = 0,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(screenWidth, screenHeight);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: ScrollablePositionedList.builder(
          itemCount: defaultItemCount,
          itemScrollController: itemScrollController,
          itemPositionsListener: itemPositionsListener,
          scrollOffsetListener: scrollOffsetListener,
          initialScrollIndex: initialIndex,
          itemBuilder: (context, index) =>
              SizedBox(height: itemHeight, child: Text('Item $index')),
        ),
      ),
    );
  }

  group('Task 2: scrollTo future completes when canceled before start', () {
    testWidgets('canceled by jumpTo before the next frame', (tester) async {
      final itemScrollController = ItemScrollController();
      await setUpWidgetTest(tester, itemScrollController: itemScrollController);

      var completed = false;
      unawaited(
        itemScrollController
            .scrollTo(index: 300, duration: scrollDuration)
            .then((_) => completed = true),
      );
      itemScrollController.jumpTo(index: 50);
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(find.text('Item 50'), findsOneWidget);
    });

    testWidgets('canceled by a pointer-down before the next frame', (
      tester,
    ) async {
      final itemScrollController = ItemScrollController();
      await setUpWidgetTest(tester, itemScrollController: itemScrollController);

      var completed = false;
      unawaited(
        itemScrollController
            .scrollTo(index: 300, duration: scrollDuration)
            .then((_) => completed = true),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ScrollablePositionedList)),
      );
      await gesture.up();
      await tester.pumpAndSettle();

      expect(completed, isTrue);
    });

    testWidgets('a scrollTo issued right after the cancel still runs', (
      tester,
    ) async {
      final itemScrollController = ItemScrollController();
      final itemPositionsListener = ItemPositionsListener.create();
      await setUpWidgetTest(
        tester,
        itemScrollController: itemScrollController,
        itemPositionsListener: itemPositionsListener,
      );

      var firstCompleted = false;
      var secondCompleted = false;
      unawaited(
        itemScrollController
            .scrollTo(index: 300, duration: scrollDuration)
            .then((_) => firstCompleted = true),
      );
      itemScrollController.jumpTo(index: 50);
      unawaited(
        itemScrollController
            .scrollTo(index: 200, duration: scrollDuration)
            .then((_) => secondCompleted = true),
      );
      await tester.pumpAndSettle();

      expect(firstCompleted, isTrue);
      expect(secondCompleted, isTrue);
      expect(
        itemPositionsListener.itemPositions.value
            .firstWhere((position) => position.index == 200)
            .itemLeadingEdge,
        0,
      );
    });
  });

  group('Task 3: jumpTo does not report a fake offset delta', () {
    testWidgets('no delta with recordProgrammaticScrolls: false', (
      tester,
    ) async {
      final itemScrollController = ItemScrollController();
      final scrollOffsetListener = ScrollOffsetListener.create(
        recordProgrammaticScrolls: false,
      );
      final deltas = <double>[];
      final subscription = scrollOffsetListener.changes.listen(deltas.add);
      addTearDown(subscription.cancel);
      await setUpWidgetTest(
        tester,
        itemScrollController: itemScrollController,
        scrollOffsetListener: scrollOffsetListener,
        initialIndex: 5,
      );

      // Scroll by hand so the primary controller has a non-zero offset.
      await tester.drag(
        find.byType(ScrollablePositionedList),
        const Offset(0, -50),
      );
      await tester.pumpAndSettle();
      expect(deltas.fold<double>(0, (a, b) => a + b), 50);
      deltas.clear();

      itemScrollController.jumpTo(index: 100);
      await tester.pumpAndSettle();

      expect(find.text('Item 100'), findsOneWidget);
      expect(deltas, isEmpty);
    });
  });

  group('Task 4: long scroll direction follows what is on screen', () {
    int firstVisibleIndex(ItemPositionsListener listener) => listener
        .itemPositions
        .value
        .map((position) => position.index)
        .reduce((a, b) => a < b ? a : b);

    testWidgets('scrolls backward after a manual drag past the target', (
      tester,
    ) async {
      final itemScrollController = ItemScrollController();
      final itemPositionsListener = ItemPositionsListener.create();
      await setUpWidgetTest(
        tester,
        itemScrollController: itemScrollController,
        itemPositionsListener: itemPositionsListener,
      );

      // Anchor the list at 50, then drag by hand to around item 200. The
      // list's anchor (`primary.target`) stays 50.
      itemScrollController.jumpTo(index: 50);
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(ScrollablePositionedList),
        const Offset(0, -150 * itemHeight),
      );
      await tester.pumpAndSettle();
      final start = firstVisibleIndex(itemPositionsListener);
      expect(start, greaterThan(150));

      unawaited(
        itemScrollController.scrollTo(index: 100, duration: scrollDuration),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // While transitioning, the reported positions come from the list that
      // was on screen; it must move toward 100, not away from it.
      expect(firstVisibleIndex(itemPositionsListener), lessThan(start));

      await tester.pumpAndSettle();
      expect(firstVisibleIndex(itemPositionsListener), 100);
    });
  });

  group('Task 6: unattached controllers fail with a descriptive assert', () {
    final notAttached = isA<AssertionError>().having(
      (error) => error.message,
      'message',
      contains('is not attached to a ScrollablePositionedList'),
    );

    test('ItemScrollController.jumpTo', () {
      expect(
        () => ItemScrollController().jumpTo(index: 0),
        throwsA(notAttached),
      );
    });

    test('ScrollOffsetController.animateScroll', () async {
      await expectLater(
        ScrollOffsetController().animateScroll(
          offset: 10,
          duration: scrollDuration,
        ),
        throwsA(notAttached),
      );
    });
  });

  group('Task 8: position listeners only fire when positions change', () {
    testWidgets('parent rebuild with identical props does not notify', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(screenWidth, screenHeight);
      addTearDown(tester.view.reset);
      final itemPositionsListener = ItemPositionsListener.create();
      late StateSetter rebuildParent;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuildParent = setState;
              return ScrollablePositionedList.builder(
                itemCount: defaultItemCount,
                itemPositionsListener: itemPositionsListener,
                itemBuilder: (context, index) =>
                    SizedBox(height: itemHeight, child: Text('Item $index')),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(itemPositionsListener.itemPositions.value, isNotEmpty);

      var notifications = 0;
      void onPositions() => notifications++;
      itemPositionsListener.itemPositions.addListener(onPositions);
      addTearDown(
        () => itemPositionsListener.itemPositions.removeListener(onPositions),
      );

      for (var i = 0; i < 3; i++) {
        rebuildParent(() {});
        await tester.pumpAndSettle();
      }

      expect(notifications, 0);
    });

    testWidgets('positions still update after the primary/secondary swap', (
      tester,
    ) async {
      final itemScrollController = ItemScrollController();
      final itemPositionsListener = ItemPositionsListener.create();
      await setUpWidgetTest(
        tester,
        itemScrollController: itemScrollController,
        itemPositionsListener: itemPositionsListener,
      );

      // Far enough to use the two-list transition, which ends in a swap.
      unawaited(
        itemScrollController.scrollTo(index: 300, duration: scrollDuration),
      );
      await tester.pumpAndSettle();
      final positions = itemPositionsListener.itemPositions.value;
      expect(
        positions.firstWhere((position) => position.index == 300)
            .itemLeadingEdge,
        0,
      );
      expect(positions.every((position) => position.index >= 300), isTrue);

      // And again after a manual drag on the new primary.
      await tester.drag(
        find.byType(ScrollablePositionedList),
        const Offset(0, -2 * itemHeight),
      );
      await tester.pumpAndSettle();
      expect(
        itemPositionsListener.itemPositions.value
            .firstWhere((position) => position.index == 302)
            .itemLeadingEdge,
        0,
      );
    });
  });

  group('Task 9: secondary-list frames do not redo position work', () {
    testWidgets('at most one position update per frame while transitioning', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(screenWidth, screenHeight);
      addTearDown(tester.view.reset);
      final itemScrollController = ItemScrollController();
      final bucket = _CountingBucket();
      await tester.pumpWidget(
        MaterialApp(
          home: PageStorage(
            bucket: bucket,
            child: ScrollablePositionedList.builder(
              itemCount: defaultItemCount,
              itemScrollController: itemScrollController,
              itemBuilder: (context, index) =>
                  SizedBox(height: itemHeight, child: Text('Item $index')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      unawaited(
        itemScrollController.scrollTo(index: 300, duration: scrollDuration),
      );
      bucket.writes = 0;
      const frame = Duration(milliseconds: 16);
      var frames = 0;
      for (; frames * 16 < 1200; frames++) {
        await tester.pump(frame);
      }
      await tester.pumpAndSettle();

      // One write per frame from the primary list, plus one after the swap.
      expect(bucket.writes, lessThanOrEqualTo(frames + 1));
      expect(find.text('Item 300'), findsOneWidget);
    });
  });

  group('Task 11: scrollTo future completes when the list is disposed', () {
    testWidgets('list replaced before the transition starts', (tester) async {
      final itemScrollController = ItemScrollController();
      await setUpWidgetTest(tester, itemScrollController: itemScrollController);

      var completed = false;
      unawaited(
        itemScrollController
            .scrollTo(index: 300, duration: scrollDuration)
            .then((_) => completed = true),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      expect(completed, isTrue);
    });
  });

  group('Task 15: re-entrant scrollTo tolerates disposal', () {
    testWidgets('list disposed before the deferred scroll starts', (
      tester,
    ) async {
      final itemScrollController = ItemScrollController();
      await setUpWidgetTest(tester, itemScrollController: itemScrollController);

      unawaited(
        itemScrollController.scrollTo(index: 300, duration: scrollDuration),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Issued mid-transition, so its start is deferred to a post-frame
      // callback, which runs after the list is disposed in the next frame.
      var completed = false;
      unawaited(
        itemScrollController
            .scrollTo(index: 50, duration: scrollDuration)
            .then((_) => completed = true),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(completed, isTrue);
    });
  });

  group('Task 12: long-scroll start callback tolerates disposal', () {
    testWidgets('list disposed after the secondary list mounts, same frame', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(screenWidth, screenHeight);
      addTearDown(tester.view.reset);
      final itemScrollController = ItemScrollController();
      final list = ScrollablePositionedList.builder(
        itemCount: defaultItemCount,
        itemScrollController: itemScrollController,
        itemBuilder: (context, index) =>
            SizedBox(height: itemHeight, child: Text('Item $index')),
      );
      late StateSetter rebuildParent;
      var layoutTwice = false;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuildParent = setState;
              return _LayoutTwice(
                enabled: layoutTwice,
                child: LayoutBuilder(
                  builder: (context, constraints) =>
                      constraints.maxHeight > screenHeight / 2
                      ? list
                      : const SizedBox(),
                ),
              );
            },
          ),
        ),
      );

      var completed = false;
      unawaited(
        itemScrollController
            .scrollTo(index: 300, duration: scrollDuration)
            .then((_) => completed = true),
      );
      // In the next frame the list builds (and mounts) its secondary list on
      // the first layout pass, then is removed on the second pass and disposed
      // before the start callback's post-frame callback runs.
      rebuildParent(() => layoutTwice = true);
      await tester.pumpAndSettle();

      expect(find.byType(ScrollablePositionedList), findsNothing);
      // Before task 11's fix: `AnimationController(vsync: this)` threw
      // "This widget has been unmounted" and the future never completed.
      expect(tester.takeException(), isNull);
      expect(completed, isTrue);
    });
  });

  group('Task 13: reordered but identical positions do not notify', () {
    testWidgets('jumpTo the item already at the top', (tester) async {
      final itemScrollController = ItemScrollController();
      final itemPositionsListener = ItemPositionsListener.create();
      await setUpWidgetTest(
        tester,
        itemScrollController: itemScrollController,
        itemPositionsListener: itemPositionsListener,
      );
      // Drag far enough that the first items leave the cache extent, then back,
      // so the visible items re-register (and are reported) out of index order.
      await tester.drag(
        find.byType(ScrollablePositionedList),
        const Offset(0, -45 * itemHeight),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(ScrollablePositionedList),
        const Offset(0, 40 * itemHeight),
      );
      await tester.pumpAndSettle();
      final before = itemPositionsListener.itemPositions.value.toList();
      expect(
        before.firstWhere((position) => position.index == 5).itemLeadingEdge,
        0,
      );

      var notifications = 0;
      void onPositions() => notifications++;
      itemPositionsListener.itemPositions.addListener(onPositions);
      addTearDown(
        () => itemPositionsListener.itemPositions.removeListener(onPositions),
      );

      // Re-anchors the list at item 5, which rebuilds its items, but nothing
      // moves on screen.
      itemScrollController.jumpTo(index: 5);
      await tester.pumpAndSettle();

      expect(
        itemPositionsListener.itemPositions.value.toSet(),
        before.toSet(),
      );
      expect(notifications, 0);
    });
  });
}

/// Lays its child out twice per layout when [enabled]: first slightly smaller
/// than its own constraints, then at a quarter of their height. Lets a test
/// remove a widget in the same frame, after it has been laid out.
class _LayoutTwice extends SingleChildRenderObjectWidget {
  const _LayoutTwice({required this.enabled, super.child});

  final bool enabled;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLayoutTwice(enabled);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderLayoutTwice renderObject,
  ) => renderObject.enabled = enabled;
}

class _RenderLayoutTwice extends RenderProxyBox {
  _RenderLayoutTwice(this._enabled);

  bool _enabled;
  set enabled(bool value) {
    if (value == _enabled) return;
    _enabled = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child!;
    if (!_enabled) {
      child.layout(constraints, parentUsesSize: true);
    } else {
      final biggest = constraints.biggest;
      child.layout(
        BoxConstraints.tight(Size(biggest.width, biggest.height - 1)),
      );
      child.layout(
        BoxConstraints.tight(Size(biggest.width, biggest.height / 4)),
      );
    }
    size = constraints.biggest;
  }
}

class _CountingBucket extends PageStorageBucket {
  int writes = 0;

  @override
  void writeState(BuildContext context, dynamic data, {Object? identifier}) {
    writes++;
    super.writeState(context, data, identifier: identifier);
  }
}
