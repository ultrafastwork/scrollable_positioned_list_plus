// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollable_positioned_list_plus/scrollable_positioned_list_plus.dart';

import 'package:scrollable_positioned_list_plus_example/main.dart';

/// Pumps the example page into an 800x900 logical-pixel view.
Future<void> pumpExample(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(800, 900)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    const MaterialApp(home: ScrollablePositionedListPage()),
  );
}

void main() {
  testWidgets('Start at 0', (WidgetTester tester) async {
    await pumpExample(tester);
    await tester.pump();
    expect(
      tester.getTopLeft(item(0)).dy -
          tester.getTopLeft(find.byType(ScrollablePositionedList)).dy,
      0,
    );
    expect(find.text('First Item: 0'), findsOneWidget);
  });

  testWidgets('Scroll Up a little', (WidgetTester tester) async {
    await pumpExample(tester);
    await tester.drag(
      find.byType(ScrollablePositionedListPage),
      const Offset(0, -5),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('First Item: 0'), findsOneWidget);
  });

  testWidgets('Scroll to 100', (WidgetTester tester) async {
    await pumpExample(tester);
    await tester.tap(find.byKey(const ValueKey<String>('Scroll100')));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(item(100)).dy -
          tester.getTopLeft(find.byType(ScrollablePositionedList)).dy,
      0,
    );
    expect(find.text('First Item: 100'), findsOneWidget);
  });

  testWidgets('Jump to 1000', (WidgetTester tester) async {
    await pumpExample(tester);
    await tester.tap(find.byKey(const ValueKey<String>('Jump1000')));
    await tester.pump();
    await tester.pump();
    expect(
      tester.getTopLeft(item(1000)).dy -
          tester.getTopLeft(find.byType(ScrollablePositionedList)).dy,
      0,
    );
    expect(find.text('First Item: 1000'), findsOneWidget);
  });

  testWidgets('Scroll to 1000', (WidgetTester tester) async {
    await pumpExample(tester);
    await tester.tap(find.byKey(const ValueKey<String>('Scroll1000')));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(item(1000)).dy -
          tester.getTopLeft(find.byType(ScrollablePositionedList)).dy,
      0,
    );
    expect(find.text('First Item: 1000'), findsOneWidget);
  });
}

Finder item(int index) => find.ancestor(
  of: find.text('Item $index'),
  matching: find.byType(SizedBox),
);
