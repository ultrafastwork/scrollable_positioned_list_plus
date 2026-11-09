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
}
