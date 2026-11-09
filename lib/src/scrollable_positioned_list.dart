// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'item_positions_listener.dart';
import 'item_positions_notifier.dart';
import 'positioned_list.dart';
import 'post_mount_callback.dart';
import 'scroll_offset_listener.dart';
import 'scroll_offset_notifier.dart';

/// Number of screens to scroll when scrolling a long distance.
const int _screenScrollCount = 2;

/// A scrollable list of widgets similar to [ListView], except scroll control
/// and position reporting is based on index rather than pixel offset.
///
/// [ScrollablePositionedList] lays out children in the same way as [ListView].
///
/// The list can be displayed with the item at [initialScrollIndex] positioned
/// at a particular [initialAlignment].
///
/// The [itemScrollController] can be used to scroll or jump to particular items
/// in the list.  The [itemPositionsNotifier] can be used to get a list of items
/// currently laid out by the list.
///
/// The [scrollOffsetListener] can be used to get updates about scroll position
/// changes.
///
/// All other parameters are the same as specified in [ListView].
class ScrollablePositionedList extends StatefulWidget {
  /// Create a [ScrollablePositionedList] whose items are provided by
  /// [itemBuilder].
  const ScrollablePositionedList.builder({
    required this.itemCount,
    required this.itemBuilder,
    super.key,
    this.itemScrollController,
    this.shrinkWrap = false,
    ItemPositionsListener? itemPositionsListener,
    this.scrollOffsetController,
    ScrollOffsetListener? scrollOffsetListener,
    this.initialScrollIndex = 0,
    this.initialAlignment = 0,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.physics,
    this.semanticChildCount,
    this.padding,
    this.addSemanticIndexes = true,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.minCacheExtent,
  }) : itemPositionsNotifier = itemPositionsListener as ItemPositionsNotifier?,
       scrollOffsetNotifier = scrollOffsetListener as ScrollOffsetNotifier?,
       separatorBuilder = null;

  /// Create a [ScrollablePositionedList] whose items are provided by
  /// [itemBuilder] and separators provided by [separatorBuilder].
  const ScrollablePositionedList.separated({
    required this.itemCount,
    required this.itemBuilder,
    required this.separatorBuilder,
    super.key,
    this.shrinkWrap = false,
    this.itemScrollController,
    ItemPositionsListener? itemPositionsListener,
    this.scrollOffsetController,
    ScrollOffsetListener? scrollOffsetListener,
    this.initialScrollIndex = 0,
    this.initialAlignment = 0,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.physics,
    this.semanticChildCount,
    this.padding,
    this.addSemanticIndexes = true,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.minCacheExtent,
  }) : assert(separatorBuilder != null),
       itemPositionsNotifier = itemPositionsListener as ItemPositionsNotifier?,
       scrollOffsetNotifier = scrollOffsetListener as ScrollOffsetNotifier?;

  /// Number of items the [itemBuilder] can produce.
  final int itemCount;

  /// Called to build children for the list with
  /// 0 <= index < itemCount.
  final IndexedWidgetBuilder itemBuilder;

  /// Called to build separators for between each item in the list.
  /// Called with 0 <= index < itemCount - 1.
  final IndexedWidgetBuilder? separatorBuilder;

  /// Controller for jumping or scrolling to an item.
  final ItemScrollController? itemScrollController;

  /// Notifier that reports the items laid out in the list after each frame.
  final ItemPositionsNotifier? itemPositionsNotifier;

  /// Controller for scrolling a number of pixels relative to the current
  /// scroll offset.
  final ScrollOffsetController? scrollOffsetController;

  /// Notifier that reports the changes to the scroll offset.
  final ScrollOffsetNotifier? scrollOffsetNotifier;

  /// Index of an item to initially align within the viewport.
  final int initialScrollIndex;

  /// Determines where the leading edge of the item at [initialScrollIndex]
  /// should be placed.
  ///
  /// See [ItemScrollController.jumpTo] for an explanation of alignment.
  final double initialAlignment;

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

  /// The number of children that will contribute semantic information.
  ///
  /// See [ScrollView.semanticChildCount] for more information.
  final int? semanticChildCount;

  /// The amount of space by which to inset the children.
  final EdgeInsets? padding;

  /// Whether to wrap each child in an [IndexedSemantics].
  ///
  /// See [SliverChildBuilderDelegate.addSemanticIndexes].
  final bool addSemanticIndexes;

  /// Whether to wrap each child in an [AutomaticKeepAlive].
  ///
  /// See [SliverChildBuilderDelegate.addAutomaticKeepAlives].
  final bool addAutomaticKeepAlives;

  /// Whether to wrap each child in a [RepaintBoundary].
  ///
  /// See [SliverChildBuilderDelegate.addRepaintBoundaries].
  final bool addRepaintBoundaries;

  /// The minimum cache extent, in logical pixels, used by the underlying
  /// scroll lists. See [ScrollView.scrollCacheExtent].
  ///
  /// Note that the [ScrollablePositionedList] uses two lists to simulate long
  /// scrolls, so using the [ItemScrollController.scrollTo] method may result
  /// in builds of widgets that would otherwise already be built in the
  /// cache extent.
  final double? minCacheExtent;

  @override
  State<StatefulWidget> createState() => _ScrollablePositionedListState();
}

/// Controller to jump or scroll to a particular position in a
/// [ScrollablePositionedList].
class ItemScrollController {
  /// Whether any ScrollablePositionedList objects are attached this object.
  ///
  /// If `false`, then [jumpTo] and [scrollTo] must not be called.
  bool get isAttached => _scrollableListState != null;

  _ScrollablePositionedListState? _scrollableListState;

  /// Immediately, without animation, reconfigure the list so that the item at
  /// [index]'s leading edge is at the given [alignment].
  ///
  /// The [alignment] specifies the desired position for the leading edge of the
  /// item.  The [alignment] is expected to be a value in the range \[0.0, 1.0\]
  /// and represents a proportion along the main axis of the viewport.
  ///
  /// For a vertically scrolling view that is not reversed:
  /// * 0 aligns the top edge of the item with the top edge of the view.
  /// * 1 aligns the top edge of the item with the bottom of the view.
  /// * 0.5 aligns the top edge of the item with the center of the view.
  ///
  /// For a horizontally scrolling view that is not reversed:
  /// * 0 aligns the left edge of the item with the left edge of the view
  /// * 1 aligns the left edge of the item with the right edge of the view.
  /// * 0.5 aligns the left edge of the item with the center of the view.
  void jumpTo({required int index, double alignment = 0}) {
    _scrollableListState!._jumpTo(index: index, alignment: alignment);
  }

  /// Animate the list over [duration] using the given [curve] such that the
  /// item at [index] ends up with its leading edge at the given [alignment].
  /// See [jumpTo] for an explanation of alignment.
  ///
  /// The [duration] must be greater than 0; otherwise, use [jumpTo].
  ///
  /// When item position is not available, because it's too far, the scroll
  /// is composed into three phases:
  ///
  ///  1. The currently displayed list view starts scrolling.
  ///  2. Another list view, which scrolls with the same speed, fades over the
  ///     first one and shows items that are close to the scroll target.
  ///  3. The second list view scrolls and stops on the target.
  ///
  /// The [opacityAnimationWeights] can be used to apply custom weights to these
  /// three stages of this animation. The default weights, `[40, 20, 40]`, are
  /// good with default [Curves.linear].  Different weights might be better for
  /// other cases.  For example, if you use [Curves.easeOut], consider setting
  /// [opacityAnimationWeights] to `[20, 20, 60]`.
  ///
  /// See [TweenSequenceItem.weight] for more info.
  Future<void> scrollTo({
    required int index,
    double alignment = 0,
    required Duration duration,
    Curve curve = Curves.linear,
    List<double> opacityAnimationWeights = const [40, 20, 40],
  }) {
    assert(_scrollableListState != null);
    assert(opacityAnimationWeights.length == 3);
    assert(duration > Duration.zero);
    return _scrollableListState!._scrollTo(
      index: index,
      alignment: alignment,
      duration: duration,
      curve: curve,
      opacityAnimationWeights: opacityAnimationWeights,
    );
  }

  void _attach(_ScrollablePositionedListState scrollableListState) {
    assert(_scrollableListState == null);
    _scrollableListState = scrollableListState;
  }

  void _detach() {
    _scrollableListState = null;
  }
}

/// Controller to scroll a certain number of pixels relative to the current
/// scroll offset.
///
/// Scrolls [offset] pixels relative to the current scroll offset. [offset] can
/// be positive or negative.
///
/// This is an experimental API and is subject to change.
/// Behavior may be ill-defined in some cases.  Please file bugs.
class ScrollOffsetController {
  /// Animates the list by [offset] pixels over [duration] using [curve].
  Future<void> animateScroll({
    required double offset,
    required Duration duration,
    Curve curve = Curves.linear,
  }) async {
    final currentPosition =
        _scrollableListState!.primary.scrollController.offset;
    final newPosition = currentPosition + offset;
    await _scrollableListState!.primary.scrollController.animateTo(
      newPosition,
      duration: duration,
      curve: curve,
    );
  }

  _ScrollablePositionedListState? _scrollableListState;

  void _attach(_ScrollablePositionedListState scrollableListState) {
    assert(_scrollableListState == null);
    _scrollableListState = scrollableListState;
  }

  void _detach() {
    _scrollableListState = null;
  }
}

class _ScrollablePositionedListState extends State<ScrollablePositionedList>
    with TickerProviderStateMixin {
  /// Details for the primary (active) [ListView].
  var primary = _ListDisplayDetails(const ValueKey('Ping'));

  /// Details for the secondary (transitional) [ListView] that is temporarily
  /// shown when scrolling a long distance.
  var secondary = _ListDisplayDetails(const ValueKey('Pong'));

  final opacity = ProxyAnimation(const AlwaysStoppedAnimation<double>(0));

  /// Opacity of the primary list. Cached so [FadeTransition] doesn't
  /// resubscribe to a fresh animation object on every build.
  late final Animation<double> _primaryOpacity = ReverseAnimation(opacity);

  void Function() startAnimationCallback = () {};

  /// Completers awaited by a long-distance scroll whose
  /// [startAnimationCallback] hasn't run yet. Completed by
  /// [_cancelPendingStart] so an abandoned scroll's future doesn't hang.
  List<Completer<void>>? _pendingStartCompleters;

  /// Identifies the latest long-distance scroll, so a superseded one doesn't
  /// stop its successor's transition when its own future completes.
  int _transitionId = 0;

  bool _isTransitioning = false;

  AnimationController? _animationController;

  double previousOffset = 0;

  @override
  void initState() {
    super.initState();
    final initialPosition =
        PageStorage.maybeOf(context)?.readState(context) as ItemPosition?;
    primary.target = initialPosition?.index ?? widget.initialScrollIndex;
    primary.alignment =
        initialPosition?.itemLeadingEdge ?? widget.initialAlignment;
    if (widget.itemCount > 0 && primary.target > widget.itemCount - 1) {
      primary.target = widget.itemCount - 1;
    }
    widget.itemScrollController?._attach(this);
    widget.scrollOffsetController?._attach(this);
    primary.itemPositionsNotifier.itemPositions.addListener(_updatePositions);
    secondary.itemPositionsNotifier.itemPositions.addListener(_updatePositions);
    // Listen on both controllers: [primary] and [secondary] swap roles after a
    // long-distance scroll, and offset changes must keep being reported from
    // whichever one is currently primary.
    final pingController = primary.scrollController;
    final pongController = secondary.scrollController;
    _pingScrollListener = () => _onScroll(pingController);
    _pongScrollListener = () => _onScroll(pongController);
    pingController.addListener(_pingScrollListener);
    pongController.addListener(_pongScrollListener);
  }

  late final VoidCallback _pingScrollListener;
  late final VoidCallback _pongScrollListener;

  void _onScroll(ScrollController source) {
    if (!identical(source, primary.scrollController)) return;
    final currentOffset = source.offset;
    final offsetChange = currentOffset - previousOffset;
    previousOffset = currentOffset;
    if (!_isTransitioning ||
        (widget.scrollOffsetNotifier?.recordProgrammaticScrolls ?? false)) {
      widget.scrollOffsetNotifier?.changeController.add(offsetChange);
    }
  }

  @override
  void activate() {
    super.activate();
    widget.itemScrollController?._attach(this);
    widget.scrollOffsetController?._attach(this);
  }

  @override
  void deactivate() {
    widget.itemScrollController?._detach();
    widget.scrollOffsetController?._detach();
    super.deactivate();
  }

  @override
  void dispose() {
    primary.itemPositionsNotifier.itemPositions.removeListener(
      _updatePositions,
    );
    secondary.itemPositionsNotifier.itemPositions.removeListener(
      _updatePositions,
    );
    _animationController?.dispose();
    for (final details in [primary, secondary]) {
      details.scrollController.dispose();
      details.itemPositionsNotifier.itemPositions.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(ScrollablePositionedList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemScrollController?._scrollableListState == this) {
      oldWidget.itemScrollController?._detach();
    }
    if (widget.itemScrollController?._scrollableListState != this) {
      widget.itemScrollController?._detach();
      widget.itemScrollController?._attach(this);
    }
    if (oldWidget.scrollOffsetController?._scrollableListState == this) {
      oldWidget.scrollOffsetController?._detach();
    }
    if (widget.scrollOffsetController?._scrollableListState != this) {
      widget.scrollOffsetController?._detach();
      widget.scrollOffsetController?._attach(this);
    }

    // No setState needed: build always runs after didUpdateWidget.
    if (widget.itemCount == 0) {
      primary.target = 0;
      secondary.target = 0;
    } else {
      final lastIndex = widget.itemCount - 1;
      if (primary.target > lastIndex) primary.target = lastIndex;
      if (secondary.target > lastIndex) secondary.target = lastIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cacheExtent = _cacheExtent(constraints);
        return Listener(
          onPointerDown: (_) => _stopScroll(canceled: true),
          child: Stack(
            children: <Widget>[
              PostMountCallback(
                key: primary.key,
                callback: startAnimationCallback,
                child: FadeTransition(
                  opacity: _primaryOpacity,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (_) => _isTransitioning,
                    child: PositionedList(
                      itemBuilder: widget.itemBuilder,
                      separatorBuilder: widget.separatorBuilder,
                      itemCount: widget.itemCount,
                      positionedIndex: primary.target,
                      controller: primary.scrollController,
                      itemPositionsNotifier: primary.itemPositionsNotifier,
                      scrollDirection: widget.scrollDirection,
                      reverse: widget.reverse,
                      cacheExtent: cacheExtent,
                      alignment: primary.alignment,
                      physics: widget.physics,
                      shrinkWrap: widget.shrinkWrap,
                      addSemanticIndexes: widget.addSemanticIndexes,
                      semanticChildCount: widget.semanticChildCount,
                      padding: widget.padding,
                      addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
                      addRepaintBoundaries: widget.addRepaintBoundaries,
                    ),
                  ),
                ),
              ),
              if (_isTransitioning)
                PostMountCallback(
                  key: secondary.key,
                  callback: startAnimationCallback,
                  child: FadeTransition(
                    opacity: opacity,
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (_) => false,
                      child: PositionedList(
                        itemBuilder: widget.itemBuilder,
                        separatorBuilder: widget.separatorBuilder,
                        itemCount: widget.itemCount,
                        itemPositionsNotifier: secondary.itemPositionsNotifier,
                        positionedIndex: secondary.target,
                        controller: secondary.scrollController,
                        scrollDirection: widget.scrollDirection,
                        reverse: widget.reverse,
                        cacheExtent: cacheExtent,
                        alignment: secondary.alignment,
                        physics: widget.physics,
                        shrinkWrap: widget.shrinkWrap,
                        addSemanticIndexes: widget.addSemanticIndexes,
                        semanticChildCount: widget.semanticChildCount,
                        padding: widget.padding,
                        addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
                        addRepaintBoundaries: widget.addRepaintBoundaries,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  double _cacheExtent(BoxConstraints constraints) => max(
    (widget.scrollDirection == Axis.vertical
            ? constraints.maxHeight
            : constraints.maxWidth) *
        _screenScrollCount,
    widget.minCacheExtent ?? 0,
  );

  /// Clamps [index] into `[0, itemCount - 1]` (or 0 for an empty list), so an
  /// out-of-range request never reaches [ScrollablePositionedList.itemBuilder].
  int _clampIndex(int index) => index.clamp(0, max(0, widget.itemCount - 1));

  void _jumpTo({required int index, required double alignment}) {
    _stopScroll(canceled: true);
    index = _clampIndex(index);
    setState(() {
      primary.scrollController.jumpTo(0);
      primary.target = index;
      primary.alignment = alignment;
    });
  }

  Future<void> _scrollTo({
    required int index,
    required double alignment,
    required Duration duration,
    Curve curve = Curves.linear,
    required List<double> opacityAnimationWeights,
  }) async {
    index = _clampIndex(index);
    if (_isTransitioning) {
      final scrollCompleter = Completer<void>();
      _stopScroll(canceled: true);
      SchedulerBinding.instance.addPostFrameCallback((_) async {
        await _startScroll(
          index: index,
          alignment: alignment,
          duration: duration,
          curve: curve,
          opacityAnimationWeights: opacityAnimationWeights,
        );
        scrollCompleter.complete();
      });
      await scrollCompleter.future;
    } else {
      await _startScroll(
        index: index,
        alignment: alignment,
        duration: duration,
        curve: curve,
        opacityAnimationWeights: opacityAnimationWeights,
      );
    }
  }

  Future<void> _startScroll({
    required int index,
    required double alignment,
    required Duration duration,
    Curve curve = Curves.linear,
    required List<double> opacityAnimationWeights,
  }) async {
    // Compare against what's on screen: primary.target is only the last
    // anchor and goes stale once the user scrolls by hand.
    final visibleIndices = primary.itemPositionsNotifier.itemPositions.value
        .where(
          (position) =>
              position.itemLeadingEdge < 1 && position.itemTrailingEdge > 0,
        )
        .map((position) => position.index);
    final currentIndex = visibleIndices.isEmpty
        ? primary.target
        : visibleIndices.reduce(min);
    final direction = index > currentIndex ? 1 : -1;
    final itemPosition = primary.itemPositionsNotifier.itemPositions.value
        .where((itemPosition) => itemPosition.index == index)
        .firstOrNull;
    if (itemPosition != null) {
      // Scroll directly.
      final localScrollAmount =
          itemPosition.itemLeadingEdge *
          primary.scrollController.position.viewportDimension;
      await primary.scrollController.animateTo(
        primary.scrollController.offset +
            localScrollAmount -
            alignment * primary.scrollController.position.viewportDimension,
        duration: duration,
        curve: curve,
      );
    } else {
      final scrollAmount =
          _screenScrollCount *
          primary.scrollController.position.viewportDimension;
      _cancelPendingStart();
      final transitionId = ++_transitionId;
      final startCompleter = Completer<void>();
      final endCompleter = Completer<void>();
      _pendingStartCompleters = [startCompleter, endCompleter];
      startAnimationCallback = () {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (startCompleter.isCompleted) return;
          _pendingStartCompleters = null;
          startAnimationCallback = () {};
          _animationController?.dispose();
          final animationController = _animationController =
              AnimationController(vsync: this, duration: duration)..forward();
          opacity.parent = _opacityAnimation(
            opacityAnimationWeights,
          ).animate(animationController);
          secondary.scrollController.jumpTo(
            -direction *
                (_screenScrollCount *
                        primary.scrollController.position.viewportDimension -
                    alignment *
                        secondary.scrollController.position.viewportDimension),
          );

          startCompleter.complete(
            primary.scrollController.animateTo(
              primary.scrollController.offset + direction * scrollAmount,
              duration: duration,
              curve: curve,
            ),
          );
          endCompleter.complete(
            secondary.scrollController.animateTo(
              0,
              duration: duration,
              curve: curve,
            ),
          );
        });
      };
      setState(() {
        // _startScroll can be re-entrant (two scrollTo calls while
        // transitioning), so `assert(!_isTransitioning)` doesn't hold here.
        // The superseded scroll's pending start is completed above instead.
        secondary.target = index;
        secondary.alignment = alignment;
        _isTransitioning = true;
      });
      await Future.wait<void>([startCompleter.future, endCompleter.future]);
      if (transitionId == _transitionId) _stopScroll();
    }
  }

  /// Completes the futures of a long-distance scroll whose transition never
  /// started, and drops its stale [startAnimationCallback].
  void _cancelPendingStart() {
    final pending = _pendingStartCompleters;
    if (pending == null) return;
    _pendingStartCompleters = null;
    startAnimationCallback = () {};
    for (final completer in pending) {
      if (!completer.isCompleted) completer.complete();
    }
  }

  void _stopScroll({bool canceled = false}) {
    if (!_isTransitioning) {
      return;
    }

    _cancelPendingStart();

    if (canceled) {
      if (primary.scrollController.hasClients) {
        primary.scrollController.jumpTo(primary.scrollController.offset);
      }
      if (secondary.scrollController.hasClients) {
        secondary.scrollController.jumpTo(secondary.scrollController.offset);
      }
    }

    if (mounted) {
      setState(() {
        if (opacity.value >= 0.5) {
          // Secondary [ListView] is more visible than the primary; make it the
          // new primary.
          final temp = primary;
          primary = secondary;
          secondary = temp;
          // Re-baseline so the next reported delta is relative to the new
          // primary's offset, not the old one's.
          if (primary.scrollController.hasClients) {
            previousOffset = primary.scrollController.offset;
          }
        }
        _isTransitioning = false;
        opacity.parent = const AlwaysStoppedAnimation<double>(0);
      });
    }
  }

  Animatable<double> _opacityAnimation(List<double> opacityAnimationWeights) {
    const startOpacity = 0.0;
    const endOpacity = 1.0;
    return TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: ConstantTween<double>(startOpacity),
        weight: opacityAnimationWeights[0],
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: startOpacity, end: endOpacity),
        weight: opacityAnimationWeights[1],
      ),
      TweenSequenceItem<double>(
        tween: ConstantTween<double>(endOpacity),
        weight: opacityAnimationWeights[2],
      ),
    ]);
  }

  void _updatePositions() {
    // Materialize once: a lazy `where` would be re-filtered by every consumer
    // (and every listener) that iterates the reported positions.
    final itemPositions = primary.itemPositionsNotifier.itemPositions.value
        .where(
          (ItemPosition position) =>
              position.itemLeadingEdge < 1 && position.itemTrailingEdge > 0,
        )
        .toList(growable: false);
    if (itemPositions.isNotEmpty) {
      PageStorage.maybeOf(context)?.writeState(
        context,
        itemPositions.reduce(
          (value, element) =>
              value.itemLeadingEdge < element.itemLeadingEdge ? value : element,
        ),
      );
    }
    widget.itemPositionsNotifier?.itemPositions.value = itemPositions;
  }
}

class _ListDisplayDetails {
  _ListDisplayDetails(this.key);

  final itemPositionsNotifier = ItemPositionsNotifier();
  final scrollController = ScrollController(keepScrollOffset: false);

  /// The index of the item to scroll to.
  int target = 0;

  /// The desired alignment for [target].
  ///
  /// See [ItemScrollController.jumpTo] for an explanation of alignment.
  double alignment = 0;

  final Key key;
}
