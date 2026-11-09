// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A sliver whose children alternate between two fixed main-axis extents:
/// [evenExtent] for even child indices and [oddExtent] for odd ones.
///
/// Used for a separated list with fixed item and separator extents. Unlike
/// [SliverVariedExtentList], which walks every child from index 0 to find the
/// one at a scroll offset, this places children with O(1) arithmetic.
class SliverAlternatingExtentList extends SliverMultiBoxAdaptorWidget {
  /// Creates a sliver whose children alternate between [evenExtent] and
  /// [oddExtent].
  const SliverAlternatingExtentList({
    super.key,
    required super.delegate,
    required this.evenExtent,
    required this.oddExtent,
  }) : assert(evenExtent >= 0),
       assert(oddExtent >= 0);

  /// Main-axis extent of the children at even indices.
  final double evenExtent;

  /// Main-axis extent of the children at odd indices.
  final double oddExtent;

  @override
  RenderSliverAlternatingExtentList createRenderObject(BuildContext context) =>
      RenderSliverAlternatingExtentList(
        childManager: context as SliverMultiBoxAdaptorElement,
        evenExtent: evenExtent,
        oddExtent: oddExtent,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSliverAlternatingExtentList renderObject,
  ) {
    renderObject
      ..evenExtent = evenExtent
      ..oddExtent = oddExtent;
  }
}

/// The render object for [SliverAlternatingExtentList].
class RenderSliverAlternatingExtentList
    extends RenderSliverFixedExtentBoxAdaptor {
  /// Creates a render object whose children alternate between [evenExtent] and
  /// [oddExtent].
  RenderSliverAlternatingExtentList({
    required super.childManager,
    required double evenExtent,
    required double oddExtent,
  }) : _evenExtent = evenExtent,
       _oddExtent = oddExtent;

  /// Main-axis extent of the children at even indices.
  double get evenExtent => _evenExtent;
  double _evenExtent;
  set evenExtent(double value) {
    if (_evenExtent == value) return;
    _evenExtent = value;
    markNeedsLayout();
  }

  /// Main-axis extent of the children at odd indices.
  double get oddExtent => _oddExtent;
  double _oddExtent;
  set oddExtent(double value) {
    if (_oddExtent == value) return;
    _oddExtent = value;
    markNeedsLayout();
  }

  double get _pairExtent => _evenExtent + _oddExtent;

  @override
  double? get itemExtent => null;

  // Only used per child (constraints and paint extent), never in a loop: the
  // index/offset methods below are overridden with closed forms.
  @override
  ItemExtentBuilder get itemExtentBuilder =>
      (index, _) => index.isEven ? _evenExtent : _oddExtent;

  @override
  double indexToLayoutOffset(double itemExtent, int index) =>
      (index ~/ 2) * _pairExtent + (index.isOdd ? _evenExtent : 0);

  /// Index of the child whose extent contains [scrollOffset], treating an
  /// offset within [precisionErrorTolerance] of a child's start as inside it.
  int _indexAt(double scrollOffset) {
    final pair = _pairExtent;
    if (pair <= 0 || scrollOffset <= 0) return 0;
    var pairIndex = (scrollOffset / pair).floor();
    var remainder = scrollOffset - pairIndex * pair;
    if (remainder >= pair - precisionErrorTolerance) {
      pairIndex++;
      remainder = 0;
    }
    return remainder < _evenExtent - precisionErrorTolerance
        ? 2 * pairIndex
        : 2 * pairIndex + 1;
  }

  @override
  int getMinChildIndexForScrollOffset(double scrollOffset, double itemExtent) =>
      _indexAt(scrollOffset);

  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset, double itemExtent) {
    // The last child that starts before [scrollOffset].
    final index = _indexAt(scrollOffset);
    final start = indexToLayoutOffset(itemExtent, index);
    return math.max(
      0,
      scrollOffset - start <= precisionErrorTolerance ? index - 1 : index,
    );
  }

  @override
  double computeMaxScrollOffset(
    SliverConstraints constraints,
    double itemExtent,
  ) => indexToLayoutOffset(itemExtent, childManager.childCount);

  // The default estimate averages the built children, which is wrong when
  // they don't all have the same extent. The exact value is cheap here.
  @override
  double estimateMaxScrollOffset(
    SliverConstraints constraints, {
    int? firstIndex,
    int? lastIndex,
    double? leadingScrollOffset,
    double? trailingScrollOffset,
  }) => computeMaxScrollOffset(constraints, 0);
}
