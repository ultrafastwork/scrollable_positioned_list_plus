// Copyright 2026 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Regression tests for ScrollablePositionedList state handling.

import 'dart:async';

import 'package:flutter/material.dart';
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
    }, skip: _task3Skip);
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
}

/// Task 3 is NEEDS OWNER DECISION: the fix lives in
/// `.agents/tasks/task-3-jumpto-delta.patch` and isn't applied yet. Set this to
/// `false` once the owner approves and the patch is applied.
const _task3Skip = true;
