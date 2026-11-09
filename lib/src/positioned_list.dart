// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'alternating_extent_list.dart';
import 'element_registry.dart';
import 'item_positions_listener.dart';
import 'item_positions_notifier.dart';
import 'scroll_view.dart';
import 'wrapping.dart';

/// A list of widgets similar to [ListView], except scroll control
/// and position reporting is based on index rather than pixel offset.
///
/// [PositionedList] lays out children in the same way as [ListView].
///
/// The list can be displayed with the item at [positionedIndex] positioned at
/// a particular [alignment].  See `ItemScrollController.jumpTo` for an
/// explanation of alignment.
///
/// All other parameters are the same as specified in [ListView].
class PositionedList extends StatefulWidget {
  /// Create a [PositionedList].
  const PositionedList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.separatorBuilder,
    this.controller,
    this.itemPositionsNotifier,
    this.positionedIndex = 0,
    this.alignment = 0,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.shrinkWrap = false,
    this.physics,
    this.padding,
    this.cacheExtent,
    this.semanticChildCount,
    this.addSemanticIndexes = true,
    this.addRepaintBoundaries = true,
    this.addAutomaticKeepAlives = true,
    this.itemExtent,
    this.prototypeItem,
    this.separatorExtent,
    this.centerKey,
  }) : assert((positionedIndex == 0) || (positionedIndex < itemCount)),
       assert(itemExtent == null || prototypeItem == null),
       assert(
         separatorExtent == null ||
             (itemExtent != null && separatorBuilder != null),
       );

  /// Number of items the [itemBuilder] can produce.
  final int itemCount;

  /// Called to build children for the list with
  /// 0 <= index < itemCount.
  final IndexedWidgetBuilder itemBuilder;

  /// If not null, called to build separators for between each item in the list.
  /// Called with 0 <= index < itemCount - 1.
  final IndexedWidgetBuilder? separatorBuilder;

  /// An object that can be used to control the position to which this scroll
  /// view is scrolled.
  final ScrollController? controller;

  /// Notifier that reports the items laid out in the list after each frame.
  final ItemPositionsNotifier? itemPositionsNotifier;

  /// Index of an item to initially align to a position within the viewport
  /// defined by [alignment].
  final int positionedIndex;

  /// Determines where the leading edge of the item at [positionedIndex]
  /// should be placed.
  ///
  /// See `ItemScrollController.jumpTo` for an explanation of alignment.
  final double alignment;

  /// The axis along which the scroll view scrolls.
  ///
  /// Defaults to [Axis.vertical].
  final Axis scrollDirection;

  /// Whether the view scrolls in the reading direction.
  ///
  /// Defaults to false.
  ///
  /// See [ScrollView.reverse].
  final bool reverse;

  /// Whether the extent of the scroll view in the [scrollDirection] should be
  /// determined by the contents being viewed.
  ///
  ///  Defaults to false.
  ///
  /// See [ScrollView.shrinkWrap].
  final bool shrinkWrap;

  /// How the scroll view should respond to user input.
  ///
  /// For example, determines how the scroll view continues to animate after the
  /// user stops dragging the scroll view.
  ///
  /// See [ScrollView.physics].
  final ScrollPhysics? physics;

  /// The cache extent of the underlying viewport, in logical pixels.
  ///
  /// If null, the framework default is used.
  final double? cacheExtent;

  /// The number of children that will contribute semantic information.
  ///
  /// See [ScrollView.semanticChildCount] for more information.
  final int? semanticChildCount;

  /// Whether to wrap each child in an [IndexedSemantics].
  ///
  /// See [SliverChildBuilderDelegate.addSemanticIndexes].
  final bool addSemanticIndexes;

  /// The amount of space by which to inset the children.
  final EdgeInsets? padding;

  /// Whether to wrap each child in a [RepaintBoundary].
  ///
  /// See [SliverChildBuilderDelegate.addRepaintBoundaries].
  final bool addRepaintBoundaries;

  /// Whether to wrap each child in an [AutomaticKeepAlive].
  ///
  /// See [SliverChildBuilderDelegate.addAutomaticKeepAlives].
  final bool addAutomaticKeepAlives;

  /// If non-null, every item has this extent in the scroll direction.
  ///
  /// See [ListView.itemExtent].
  final double? itemExtent;

  /// If non-null, every item has the extent of this widget in the scroll
  /// direction.
  ///
  /// See [ListView.prototypeItem].
  final Widget? prototypeItem;

  /// If non-null (only with [separatorBuilder] and [itemExtent]), every
  /// separator has this extent in the scroll direction.
  final double? separatorExtent;

  /// Key for the center sliver (a [SliverPadding]), so its render object can
  /// be found. If null, a private key is used.
  final Key? centerKey;

  @override
  State<StatefulWidget> createState() => _PositionedListState();
}

class _PositionedListState extends State<PositionedList> {
  final Key _centerKey = UniqueKey();

  final registeredElements = ValueNotifier<Set<Element>?>(null);
  late final ScrollController scrollController;

  /// Whether [scrollController] was created here (and must be disposed here).
  late final bool _ownsScrollController;

  bool updateScheduled = false;

  @override
  void initState() {
    super.initState();
    _ownsScrollController = widget.controller == null;
    scrollController = widget.controller ?? ScrollController();
    scrollController.addListener(_schedulePositionNotificationUpdate);
    _schedulePositionNotificationUpdate();
  }

  @override
  void dispose() {
    scrollController.removeListener(_schedulePositionNotificationUpdate);
    if (_ownsScrollController) scrollController.dispose();
    registeredElements.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PositionedList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedulePositionNotificationUpdate();
  }

  @override
  Widget build(BuildContext context) => RegistryWidget(
    elementNotifier: registeredElements,
    child: UnboundedCustomScrollView(
      anchor: widget.alignment,
      center: widget.centerKey ?? _centerKey,
      controller: scrollController,
      scrollDirection: widget.scrollDirection,
      reverse: widget.reverse,
      scrollCacheExtent: switch (widget.cacheExtent) {
        final double pixels => ScrollCacheExtent.pixels(pixels),
        null => null,
      },
      physics: widget.physics,
      shrinkWrap: widget.shrinkWrap,
      semanticChildCount: widget.semanticChildCount ?? widget.itemCount,
      slivers: <Widget>[
        if (widget.positionedIndex > 0)
          SliverPadding(
            key: ValueKey((#leading, widget.positionedIndex)),
            padding: _leadingSliverPadding,
            // Built in reverse: odd children are items, even ones separators.
            sliver: _sliver(
              itemsAreOdd: true,
              delegate: SliverChildBuilderDelegate(
                (context, index) => widget.separatorBuilder == null
                    ? _buildItem(widget.positionedIndex - (index + 1))
                    : _buildSeparatedListElement(
                        2 * widget.positionedIndex - (index + 1),
                      ),
                childCount: widget.separatorBuilder == null
                    ? widget.positionedIndex
                    : 2 * widget.positionedIndex,
                addSemanticIndexes: false,
                addRepaintBoundaries: widget.addRepaintBoundaries,
                addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
              ),
            ),
          ),
        SliverPadding(
          key: widget.centerKey ?? _centerKey,
          padding: _centerSliverPadding,
          sliver: _sliver(
            itemsAreOdd: false,
            delegate: SliverChildBuilderDelegate(
              (context, index) => widget.separatorBuilder == null
                  ? _buildItem(index + widget.positionedIndex)
                  : _buildSeparatedListElement(
                      index + 2 * widget.positionedIndex,
                    ),
              childCount: widget.itemCount != 0 ? 1 : 0,
              addSemanticIndexes: false,
              addRepaintBoundaries: widget.addRepaintBoundaries,
              addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
            ),
          ),
        ),
        if (widget.positionedIndex >= 0 &&
            widget.positionedIndex < widget.itemCount - 1)
          SliverPadding(
            key: ValueKey((#trailing, widget.positionedIndex)),
            padding: _trailingSliverPadding,
            // Starts with the separator after the center item.
            sliver: _sliver(
              itemsAreOdd: true,
              delegate: SliverChildBuilderDelegate(
                (context, index) => widget.separatorBuilder == null
                    ? _buildItem(index + widget.positionedIndex + 1)
                    : _buildSeparatedListElement(
                        index + 2 * widget.positionedIndex + 1,
                      ),
                childCount: widget.separatorBuilder == null
                    ? widget.itemCount - widget.positionedIndex - 1
                    : 2 * (widget.itemCount - widget.positionedIndex - 1),
                addSemanticIndexes: false,
                addRepaintBoundaries: widget.addRepaintBoundaries,
                addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
              ),
            ),
          ),
      ],
    ),
  );

  /// The sliver for one of the three parts of the list: fixed-extent when an
  /// extent is given, otherwise a plain [SliverList].
  ///
  /// [itemsAreOdd] says whether, with separators, the items are this sliver's
  /// odd children (and the separators its even ones) or the other way round.
  Widget _sliver({
    required SliverChildDelegate delegate,
    required bool itemsAreOdd,
  }) {
    final itemExtent = widget.itemExtent;
    final separatorExtent = widget.separatorExtent;
    final prototypeItem = widget.prototypeItem;
    if (itemExtent != null && separatorExtent != null) {
      return SliverAlternatingExtentList(
        delegate: delegate,
        evenExtent: itemsAreOdd ? separatorExtent : itemExtent,
        oddExtent: itemsAreOdd ? itemExtent : separatorExtent,
      );
    }
    if (itemExtent != null) {
      return SliverFixedExtentList(delegate: delegate, itemExtent: itemExtent);
    }
    if (prototypeItem != null) {
      return SliverPrototypeExtentList(
        delegate: delegate,
        prototypeItem: prototypeItem,
      );
    }
    return SliverList(delegate: delegate);
  }

  Widget _buildSeparatedListElement(int index) {
    if (index.isEven) {
      return _buildItem(index ~/ 2);
    } else {
      return widget.separatorBuilder!(context, index ~/ 2);
    }
  }

  Widget _buildItem(int index) {
    return RegisteredElementWidget(
      key: ValueKey(index),
      child: widget.addSemanticIndexes
          ? IndexedSemantics(
              index: index,
              child: widget.itemBuilder(context, index),
            )
          : widget.itemBuilder(context, index),
    );
  }

  EdgeInsets get _leadingSliverPadding {
    final padding = widget.padding;
    if (padding == null) return EdgeInsets.zero;
    return switch ((widget.scrollDirection, widget.reverse)) {
      (Axis.vertical, true) => padding.copyWith(top: 0),
      (Axis.vertical, false) => padding.copyWith(bottom: 0),
      (Axis.horizontal, true) => padding.copyWith(left: 0),
      (Axis.horizontal, false) => padding.copyWith(right: 0),
    };
  }

  EdgeInsets get _centerSliverPadding {
    final padding = widget.padding;
    if (padding == null) return EdgeInsets.zero;
    final isFirst = widget.positionedIndex == 0;
    final isLast = widget.positionedIndex == widget.itemCount - 1;
    return switch ((widget.scrollDirection, widget.reverse)) {
      (Axis.vertical, true) => padding.copyWith(
        top: isLast ? padding.top : 0,
        bottom: isFirst ? padding.bottom : 0,
      ),
      (Axis.vertical, false) => padding.copyWith(
        top: isFirst ? padding.top : 0,
        bottom: isLast ? padding.bottom : 0,
      ),
      (Axis.horizontal, true) => padding.copyWith(
        left: isLast ? padding.left : 0,
        right: isFirst ? padding.right : 0,
      ),
      (Axis.horizontal, false) => padding.copyWith(
        left: isFirst ? padding.left : 0,
        right: isLast ? padding.right : 0,
      ),
    };
  }

  EdgeInsets get _trailingSliverPadding {
    final padding = widget.padding;
    if (padding == null) return EdgeInsets.zero;
    return switch ((widget.scrollDirection, widget.reverse)) {
      (Axis.vertical, true) => padding.copyWith(bottom: 0),
      (Axis.vertical, false) => padding.copyWith(top: 0),
      (Axis.horizontal, true) => padding.copyWith(right: 0),
      (Axis.horizontal, false) => padding.copyWith(left: 0),
    };
  }

  void _schedulePositionNotificationUpdate() {
    if (!updateScheduled) {
      updateScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        final elements = registeredElements.value;
        // The list may have been disposed, or not yet attached to a scroll
        // position, by the time this frame callback runs.
        if (!mounted || elements == null || !scrollController.hasClients) {
          updateScheduled = false;
          return;
        }
        final viewportDimension = scrollController.position.viewportDimension;
        final positions = <ItemPosition>[];
        RenderViewportBase? viewport;
        var anchor = 0.0;
        for (var element in elements) {
          final box = element.renderObject! as RenderBox;
          if (viewport == null) {
            viewport = RenderAbstractViewport.of(box) as RenderViewportBase?;
            anchor = switch (viewport) {
              final RenderViewport v => v.anchor,
              final CustomRenderViewport v => v.anchor,
              _ => 0.0,
            };
          }

          final key = element.widget.key! as ValueKey<int>;
          // Skip this element if `box` has never been laid out.
          if (!box.hasSize) continue;
          if (widget.scrollDirection == Axis.vertical) {
            final reveal = viewport!.getOffsetToReveal(box, 0).offset;
            if (!reveal.isFinite) continue;
            final itemOffset =
                reveal - viewport.offset.pixels + anchor * viewport.size.height;
            positions.add(
              ItemPosition(
                index: key.value,
                itemLeadingEdge: itemOffset.round() / viewportDimension,
                itemTrailingEdge:
                    (itemOffset + box.size.height).round() / viewportDimension,
              ),
            );
          } else {
            final itemOffset = box
                .localToGlobal(Offset.zero, ancestor: viewport)
                .dx;
            if (!itemOffset.isFinite) continue;
            positions.add(
              ItemPosition(
                index: key.value,
                itemLeadingEdge:
                    (widget.reverse
                            ? viewportDimension - (itemOffset + box.size.width)
                            : itemOffset)
                        .round() /
                    viewportDimension,
                itemTrailingEdge:
                    (widget.reverse
                            ? viewportDimension - itemOffset
                            : (itemOffset + box.size.width))
                        .round() /
                    viewportDimension,
              ),
            );
          }
        }
        // The registry is unordered; sort so consumers get a stable order and
        // [samePositions] can compare element-wise.
        positions.sort((a, b) => a.index.compareTo(b.index));
        final notifier = widget.itemPositionsNotifier?.itemPositions;
        // Skip the assignment (and the listener calls) when nothing moved.
        if (notifier != null && !samePositions(notifier.value, positions)) {
          notifier.value = positions;
        }
        updateScheduled = false;
      });
    }
  }
}
