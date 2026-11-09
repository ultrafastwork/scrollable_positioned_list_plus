// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollable_positioned_list_plus/scrollable_positioned_list_plus.dart';

const screenSize = 400.0;
const itemExtent = screenSize / 10.0;
const separatorExtent = 10.0;
const defaultItemCount = 500;
const scrollDuration = Duration(seconds: 1);
const tolerance = 1e-3;

enum _Mode { itemExtent, prototypeItem, separated }

void main() {
  final fadeTransitionFinder = find.descendant(
    of: find.byType(ScrollablePositionedList),
    matching: find.byType(FadeTransition),
  );

  Future<void> pumpList(
    WidgetTester tester, {
    required ItemScrollController itemScrollController,
    required ItemPositionsListener itemPositionsListener,
    _Mode mode = _Mode.itemExtent,
    Axis scrollDirection = Axis.vertical,
    bool reverse = false,
    bool shrinkWrap = false,
    EdgeInsets? padding,
    int itemCount = defaultItemCount,
    int initialScrollIndex = 0,
    double initialAlignment = 0,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(screenSize, screenSize);
    addTearDown(tester.view.reset);

    // Items deliberately ask for a different size: the list must force them
    // to the fixed extent.
    Widget item(BuildContext context, int index) =>
        SizedBox(height: 7, width: 7, child: Text('Item $index'));

    await tester.pumpWidget(
      MaterialApp(
        home: switch (mode) {
          _Mode.itemExtent => ScrollablePositionedList.builder(
            itemCount: itemCount,
            itemBuilder: item,
            itemExtent: itemExtent,
            itemScrollController: itemScrollController,
            itemPositionsListener: itemPositionsListener,
            scrollDirection: scrollDirection,
            reverse: reverse,
            shrinkWrap: shrinkWrap,
            padding: padding,
            initialScrollIndex: initialScrollIndex,
            initialAlignment: initialAlignment,
          ),
          _Mode.prototypeItem => ScrollablePositionedList.builder(
            itemCount: itemCount,
            itemBuilder: item,
            prototypeItem: const SizedBox(
              height: itemExtent,
              width: itemExtent,
            ),
            itemScrollController: itemScrollController,
            itemPositionsListener: itemPositionsListener,
            scrollDirection: scrollDirection,
            reverse: reverse,
            shrinkWrap: shrinkWrap,
            padding: padding,
            initialScrollIndex: initialScrollIndex,
            initialAlignment: initialAlignment,
          ),
          _Mode.separated => ScrollablePositionedList.separated(
            itemCount: itemCount,
            itemBuilder: item,
            separatorBuilder: (context, index) => const SizedBox.shrink(),
            itemExtent: itemExtent,
            separatorExtent: separatorExtent,
            itemScrollController: itemScrollController,
            itemPositionsListener: itemPositionsListener,
            scrollDirection: scrollDirection,
            reverse: reverse,
            shrinkWrap: shrinkWrap,
            padding: padding,
            initialScrollIndex: initialScrollIndex,
            initialAlignment: initialAlignment,
          ),
        },
      ),
    );
  }

  ItemPosition positionOf(ItemPositionsListener listener, int index) =>
      listener.itemPositions.value.firstWhere((p) => p.index == index);

  /// Scrolls and checks on every frame that no second list is faded in.
  Future<void> scrollWithoutCrossfade(
    WidgetTester tester,
    ItemScrollController controller, {
    required int index,
    double alignment = 0,
  }) async {
    var done = false;
    unawaited(
      controller
          .scrollTo(
            index: index,
            alignment: alignment,
            duration: scrollDuration,
          )
          .then((_) => done = true),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(scrollDuration ~/ 10);
      expect(fadeTransitionFinder, findsOneWidget);
    }
    await tester.pumpAndSettle();
    expect(fadeTransitionFinder, findsOneWidget);
    expect(done, isTrue);
  }

  for (final mode in _Mode.values) {
    group('${mode.name}:', () {
      final stride =
          itemExtent + (mode == _Mode.separated ? separatorExtent : 0);

      testWidgets('items are forced to the fixed extent', (tester) async {
        final itemPositionsListener = ItemPositionsListener.create();
        await pumpList(
          tester,
          mode: mode,
          itemScrollController: ItemScrollController(),
          itemPositionsListener: itemPositionsListener,
          initialScrollIndex: 50,
        );
        for (final index in [50, 51, 52]) {
          final position = positionOf(itemPositionsListener, index);
          expect(
            position.itemLeadingEdge,
            closeTo((index - 50) * stride / screenSize, tolerance),
          );
          expect(
            position.itemTrailingEdge - position.itemLeadingEdge,
            closeTo(itemExtent / screenSize, tolerance),
          );
        }
      });

      for (final alignment in [0.0, 0.5, 1.0]) {
        testWidgets('scrollTo forward and back, alignment $alignment', (
          tester,
        ) async {
          final itemScrollController = ItemScrollController();
          final itemPositionsListener = ItemPositionsListener.create();
          await pumpList(
            tester,
            mode: mode,
            itemScrollController: itemScrollController,
            itemPositionsListener: itemPositionsListener,
            initialScrollIndex: 20,
          );

          // About 6 screens forward: not built, but within the cap.
          // At alignment 1 the target is just off screen, so the listener
          // doesn't report it; check the item before it instead.
          void expectAligned(int index) {
            if (alignment < 1) {
              expect(
                positionOf(itemPositionsListener, index).itemLeadingEdge,
                closeTo(alignment, tolerance),
              );
            } else {
              expect(
                positionOf(itemPositionsListener, index - 1).itemLeadingEdge,
                closeTo(alignment - stride / screenSize, tolerance),
              );
            }
          }

          await scrollWithoutCrossfade(
            tester,
            itemScrollController,
            index: 70,
            alignment: alignment,
          );
          expectAligned(70);

          // Back past the anchor, into the leading sliver (far enough from
          // the start that no clamping is needed for alignment 1).
          await scrollWithoutCrossfade(
            tester,
            itemScrollController,
            index: 12,
            alignment: alignment,
          );
          expectAligned(12);
        });
      }

      testWidgets('scrollTo horizontal', (tester) async {
        final itemScrollController = ItemScrollController();
        final itemPositionsListener = ItemPositionsListener.create();
        await pumpList(
          tester,
          mode: mode,
          scrollDirection: Axis.horizontal,
          itemScrollController: itemScrollController,
          itemPositionsListener: itemPositionsListener,
        );
        await scrollWithoutCrossfade(
          tester,
          itemScrollController,
          index: 60,
          alignment: 0.25,
        );
        expect(
          positionOf(itemPositionsListener, 60).itemLeadingEdge,
          closeTo(0.25, tolerance),
        );
      });

      testWidgets('scrollTo reversed', (tester) async {
        final itemScrollController = ItemScrollController();
        final itemPositionsListener = ItemPositionsListener.create();
        await pumpList(
          tester,
          mode: mode,
          reverse: true,
          itemScrollController: itemScrollController,
          itemPositionsListener: itemPositionsListener,
          initialScrollIndex: 10,
        );
        await scrollWithoutCrossfade(
          tester,
          itemScrollController,
          index: 60,
          alignment: 0.5,
        );
        expect(
          positionOf(itemPositionsListener, 60).itemLeadingEdge,
          closeTo(0.5, tolerance),
        );
        await scrollWithoutCrossfade(tester, itemScrollController, index: 2);
        expect(
          positionOf(itemPositionsListener, 2).itemLeadingEdge,
          closeTo(0, tolerance),
        );
      });

      for (final initialScrollIndex in [0, 5]) {
        testWidgets('scrollTo with padding, anchored at $initialScrollIndex', (
          tester,
        ) async {
          final itemScrollController = ItemScrollController();
          final itemPositionsListener = ItemPositionsListener.create();
          await pumpList(
            tester,
            mode: mode,
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 5),
            itemScrollController: itemScrollController,
            itemPositionsListener: itemPositionsListener,
            initialScrollIndex: initialScrollIndex,
          );
          await scrollWithoutCrossfade(
            tester,
            itemScrollController,
            index: 40,
            alignment: 0.5,
          );
          expect(
            positionOf(itemPositionsListener, 40).itemLeadingEdge,
            closeTo(0.5, tolerance),
          );

          // Item 0 goes to the very top, like the default direct path does:
          // the leading padding is scrolled out of view.
          await scrollWithoutCrossfade(tester, itemScrollController, index: 0);
          expect(
            positionOf(itemPositionsListener, 0).itemLeadingEdge,
            closeTo(0, tolerance),
          );

          // Asking for more than the padding allows is clamped to the start.
          await scrollWithoutCrossfade(
            tester,
            itemScrollController,
            index: 0,
            alignment: 0.5,
          );
          expect(
            positionOf(itemPositionsListener, 0).itemLeadingEdge,
            closeTo(30 / screenSize, tolerance),
          );
        });
      }

      testWidgets('scrollTo the last item clamps to the end', (tester) async {
        final itemScrollController = ItemScrollController();
        final itemPositionsListener = ItemPositionsListener.create();
        await pumpList(
          tester,
          mode: mode,
          itemCount: 60,
          itemScrollController: itemScrollController,
          itemPositionsListener: itemPositionsListener,
        );
        await scrollWithoutCrossfade(tester, itemScrollController, index: 59);
        expect(
          positionOf(itemPositionsListener, 59).itemTrailingEdge,
          closeTo(1, tolerance),
        );
      });

      testWidgets('scrollTo with shrinkWrap', (tester) async {
        final itemScrollController = ItemScrollController();
        final itemPositionsListener = ItemPositionsListener.create();
        await pumpList(
          tester,
          mode: mode,
          shrinkWrap: true,
          itemScrollController: itemScrollController,
          itemPositionsListener: itemPositionsListener,
        );
        await scrollWithoutCrossfade(
          tester,
          itemScrollController,
          index: 50,
          alignment: 0.5,
        );
        expect(
          positionOf(itemPositionsListener, 50).itemLeadingEdge,
          closeTo(0.5, tolerance),
        );
      });

      testWidgets('scrollTo beyond the cap still crossfades', (tester) async {
        final itemScrollController = ItemScrollController();
        final itemPositionsListener = ItemPositionsListener.create();
        await pumpList(
          tester,
          mode: mode,
          itemScrollController: itemScrollController,
          itemPositionsListener: itemPositionsListener,
        );
        unawaited(
          itemScrollController.scrollTo(index: 300, duration: scrollDuration),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump(scrollDuration ~/ 2);
        expect(fadeTransitionFinder, findsNWidgets(2));
        await tester.pumpAndSettle();
        expect(
          positionOf(itemPositionsListener, 300).itemLeadingEdge,
          closeTo(0, tolerance),
        );

        // The new primary is anchored at 300; nearby scrolls are direct again.
        await scrollWithoutCrossfade(
          tester,
          itemScrollController,
          index: 250,
          alignment: 0.5,
        );
        expect(
          positionOf(itemPositionsListener, 250).itemLeadingEdge,
          closeTo(0.5, tolerance),
        );
      });

      testWidgets('dragging keeps items at fixed offsets', (tester) async {
        final itemPositionsListener = ItemPositionsListener.create();
        await pumpList(
          tester,
          mode: mode,
          itemScrollController: ItemScrollController(),
          itemPositionsListener: itemPositionsListener,
          initialScrollIndex: 100,
        );
        // Drag back into the leading sliver, then forward into the trailing.
        await tester.drag(
          find.byType(ScrollablePositionedList),
          const Offset(0, 3 * screenSize),
        );
        await tester.pumpAndSettle();
        await tester.drag(
          find.byType(ScrollablePositionedList),
          const Offset(0, -7 * screenSize),
        );
        await tester.pumpAndSettle();
        final positions = itemPositionsListener.itemPositions.value.toList();
        expect(positions, isNotEmpty);
        for (var i = 1; i < positions.length; i++) {
          expect(positions[i].index, positions[i - 1].index + 1);
          expect(
            positions[i].itemLeadingEdge - positions[i - 1].itemLeadingEdge,
            closeTo(stride / screenSize, tolerance),
          );
        }
      });
    });
  }
}
