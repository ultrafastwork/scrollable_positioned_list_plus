// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import 'item_positions_listener.dart';

/// Internal implementation of [ItemPositionsListener].
class ItemPositionsNotifier implements ItemPositionsListener {
  @override
  final ValueNotifier<Iterable<ItemPosition>> itemPositions = ValueNotifier([]);
}

/// Whether [current] already holds exactly [positions], in the same order.
///
/// Both lists are expected to be sorted by [ItemPosition.index] (positions are
/// sorted when they are collected), so an element-wise comparison is enough
/// and no temporary sets need to be allocated on every frame.
bool samePositions(
  Iterable<ItemPosition> current,
  List<ItemPosition> positions,
) => current is List<ItemPosition> && listEquals(current, positions);
