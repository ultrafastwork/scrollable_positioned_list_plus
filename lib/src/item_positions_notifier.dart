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

/// Whether [current] already holds exactly [positions], in any order.
///
/// Positions are collected from an unordered element registry, so the same
/// positions can come back in a different order.
bool samePositions(
  Iterable<ItemPosition> current,
  List<ItemPosition> positions,
) =>
    current is List<ItemPosition> &&
    (listEquals(current, positions) ||
        (current.length == positions.length &&
            setEquals(current.toSet(), positions.toSet())));
