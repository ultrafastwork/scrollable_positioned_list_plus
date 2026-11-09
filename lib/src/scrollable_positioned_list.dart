// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
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

/// With a fixed item extent, the farthest `scrollTo` target, in viewports,
/// that is animated directly instead of crossfading. Measured on a device
/// (task 20): beyond about 10 viewports, building a new screen of items on
/// every frame costs more than the crossfade.
const int _maxDirectScrollScreens = 10;

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
/// A [ScrollOffsetListener] passed as `scrollOffsetListener` can be used to get
/// updates about scroll position changes.
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
    this.itemExtent,
    this.prototypeItem,
  }) : assert(
         itemExtent == null || prototypeItem == null,
         'You can only pass itemExtent or prototypeItem, not both.',
       ),
       itemPositionsNotifier = itemPositionsListener as ItemPositionsNotifier?,
       scrollOffsetNotifier = scrollOffsetListener as ScrollOffsetNotifier?,
       separatorBuilder = null,
       separatorExtent = null;

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
    this.itemExtent,
    this.separatorExtent,
  }) : assert(separatorBuilder != null),
       assert(
         (itemExtent == null) == (separatorExtent == null),
         'Pass both itemExtent and separatorExtent, or neither.',
       ),
       itemPositionsNotifier = itemPositionsListener as ItemPositionsNotifier?,
       scrollOffsetNotifier = scrollOffsetListener as ScrollOffsetNotifier?,
       prototypeItem = null;

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

  /// If non-null, forces every item to have this extent in the scroll
  /// direction, like [ListView.itemExtent].
  ///
  /// The offset of every item is then known without building it, so
  /// [ItemScrollController.scrollTo] animates straight to targets up to about
  /// ten viewports away and lands exactly, instead of crossfading to a second
  /// list. Farther targets still crossfade.
  ///
  /// With [ScrollablePositionedList.separated], [separatorExtent] must be
  /// given too.
  final double? itemExtent;

  /// If non-null, forces every item to have the same extent as this widget in
  /// the scroll direction, like [ListView.prototypeItem]. The prototype is
  /// laid out but never shown.
  ///
  /// Has the same effect on [ItemScrollController.scrollTo] as [itemExtent].
  /// Only [ScrollablePositionedList.builder] supports it.
  final Widget? prototypeItem;

  /// The extent of every separator in the scroll direction, for
  /// [ScrollablePositionedList.separated] with an [itemExtent].
  final double? separatorExtent;

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
    assert(
      _scrollableListState != null,
      'ItemScrollController is not attached to a ScrollablePositionedList',
    );
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
    assert(
      _scrollableListState != null,
      'ItemScrollController is not attached to a ScrollablePositionedList',
    );
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
/// [animateScroll] scrolls `offset` pixels relative to the current scroll
/// offset; `offset` can be positive or negative.
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
    assert(
      _scrollableListState != null,
      'ScrollOffsetController is not attached to a ScrollablePositionedList',
    );
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
  _ListDisplayDetails primary = _ListDisplayDetails(const ValueKey('Ping'));

  /// Details for the secondary (transitional) [ListView] that is temporarily
  /// shown when scrolling a long distance.
  _ListDisplayDetails secondary = _ListDisplayDetails(const ValueKey('Pong'));

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

  /// Identifies the latest [_jumpTo] or [_scrollTo] call, so a deferred
  /// scroll that has been superseded doesn't start after its successor.
  int _scrollRequestId = 0;

  /// Request id of the [_scrollTo] whose start is waiting for a post-frame
  /// callback, if any. Later scrolls queue behind it instead of starting first.
  int? _deferredScrollId;

  bool _isTransitioning = false;

  AnimationController? _animationController;

  double previousOffset = 0;

  /// True while [_jumpTo] resets the primary controller to offset 0.
  bool _isReanchoring = false;

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
    // Only the current primary's positions are reported, so ignore updates
    // from the other list (the hidden secondary while transitioning).
    final ping = primary;
    final pong = secondary;
    ping.itemPositionsNotifier.itemPositions.addListener(() {
      if (identical(ping, primary)) _updatePositions();
    });
    pong.itemPositionsNotifier.itemPositions.addListener(() {
      if (identical(pong, primary)) _updatePositions();
    });
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
    final notifier = widget.scrollOffsetNotifier;
    if (notifier == null || _isReanchoring) return;
    if (!_isTransitioning || notifier.recordProgrammaticScrolls) {
      notifier.changeController.add(offsetChange);
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
    // The position listeners added in initState go away with the notifiers,
    // which are disposed below.
    _cancelPendingStart();
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

    // A newly passed position listener would otherwise stay empty until the
    // positions change, because the internal notifier only fires on change.
    // Hand it the current positions after this frame, not now: assigning
    // during build would call the app's listeners mid-build.
    if (widget.itemPositionsNotifier != null &&
        !identical(
          widget.itemPositionsNotifier,
          oldWidget.itemPositionsNotifier,
        )) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updatePositions();
      });
    }

    // The new widget may carry a new item builder, item count, etc.
    primary.list = null;
    secondary.list = null;

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
              _buildList(
                primary,
                opacity: _primaryOpacity,
                cacheExtent: cacheExtent,
                // Swallow the primary's notifications while transitioning.
                onNotification: (_) => _isTransitioning,
              ),
              if (_isTransitioning)
                _buildList(
                  secondary,
                  opacity: opacity,
                  cacheExtent: cacheExtent,
                  onNotification: (_) => false,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildList(
    _ListDisplayDetails details, {
    required Animation<double> opacity,
    required double cacheExtent,
    required NotificationListenerCallback<ScrollNotification> onNotification,
  }) => PostMountCallback(
    key: details.key,
    callback: startAnimationCallback,
    child: FadeTransition(
      opacity: opacity,
      child: NotificationListener<ScrollNotification>(
        onNotification: onNotification,
        child: _positionedList(details, cacheExtent),
      ),
    ),
  );

  /// The [PositionedList] for [details], reused while nothing it depends on
  /// has changed.
  ///
  /// Starting and ending a long-distance scroll rebuild this widget. Handing
  /// back the same instance lets the framework skip the list's subtree, so the
  /// items already built aren't built again in those (already expensive)
  /// frames.
  PositionedList _positionedList(
    _ListDisplayDetails details,
    double cacheExtent,
  ) {
    final cached = details.list;
    if (cached != null &&
        cached.positionedIndex == details.target &&
        cached.alignment == details.alignment &&
        cached.cacheExtent == cacheExtent) {
      return cached;
    }
    return details.list = PositionedList(
      itemBuilder: widget.itemBuilder,
      separatorBuilder: widget.separatorBuilder,
      itemCount: widget.itemCount,
      positionedIndex: details.target,
      controller: details.scrollController,
      itemPositionsNotifier: details.itemPositionsNotifier,
      scrollDirection: widget.scrollDirection,
      reverse: widget.reverse,
      cacheExtent: cacheExtent,
      alignment: details.alignment,
      physics: widget.physics,
      shrinkWrap: widget.shrinkWrap,
      addSemanticIndexes: widget.addSemanticIndexes,
      semanticChildCount: widget.semanticChildCount,
      padding: widget.padding,
      addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
      addRepaintBoundaries: widget.addRepaintBoundaries,
      itemExtent: widget.itemExtent,
      prototypeItem: widget.prototypeItem,
      separatorExtent: widget.separatorExtent,
      centerKey: _hasFixedExtent ? details.centerKey : null,
    );
  }

  bool get _hasFixedExtent =>
      widget.itemExtent != null || widget.prototypeItem != null;

  /// For a fixed-extent list, the [primary] scroll offset that puts the
  /// leading edge of the item at [index] at [alignment], clamped to the scroll
  /// range. Null if the list has no fixed extent or isn't laid out.
  ///
  /// At offset 0 the leading edge of the center sliver (item [primary]'s
  /// target, plus any padding before it) is at [primary]'s alignment, and every
  /// item after or before it is a whole number of strides away.
  double? _fixedExtentScrollOffset(int index, double alignment) {
    if (!_hasFixedExtent) return null;
    final center = primary.centerKey.currentContext?.findRenderObject();
    if (center is! RenderSliverPadding || center.geometry == null) return null;
    final sliver = center.child;
    if (sliver is! RenderSliverFixedExtentBoxAdaptor) return null;
    final itemExtent = widget.itemExtent ?? sliver.itemExtent;
    if (itemExtent == null) return null;
    final stride = itemExtent + (widget.separatorExtent ?? 0);
    final position = primary.scrollController.position;
    if (!position.hasContentDimensions || !position.hasViewportDimension) {
      return null;
    }
    final offset =
        (index - primary.target) * stride +
        center.beforePadding +
        (primary.alignment - alignment) * position.viewportDimension;
    return clampDouble(
      offset,
      position.minScrollExtent,
      position.maxScrollExtent,
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
    // Supersedes any deferred scroll; its callback sees the newer id.
    _scrollRequestId++;
    _deferredScrollId = null;
    _stopScroll(canceled: true);
    index = _clampIndex(index);
    setState(() {
      // Re-anchoring to offset 0 doesn't move anything on screen, so don't
      // report it as a scroll; _onScroll still re-baselines previousOffset.
      _isReanchoring = true;
      primary.scrollController.jumpTo(0);
      _isReanchoring = false;
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
    final requestId = ++_scrollRequestId;
    // Also defer behind a pending deferred scroll: _stopScroll has already
    // cleared _isTransitioning, and starting now would let that older scroll
    // start afterwards and cancel this one.
    if (_isTransitioning || _deferredScrollId != null) {
      final scrollCompleter = Completer<void>();
      _deferredScrollId = requestId;
      _stopScroll(canceled: true);
      SchedulerBinding.instance.addPostFrameCallback((_) async {
        if (_deferredScrollId == requestId) _deferredScrollId = null;
        if (!mounted || requestId != _scrollRequestId) {
          scrollCompleter.complete();
          return;
        }
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
    // With a fixed extent the target offset is known even for items that
    // aren't built, so animate directly as long as the distance is short
    // enough for that to stay smooth.
    var fixedOffset = _fixedExtentScrollOffset(index, alignment);
    if (fixedOffset != null &&
        (fixedOffset - primary.scrollController.offset).abs() >
            _maxDirectScrollScreens *
                primary.scrollController.position.viewportDimension) {
      fixedOffset = null;
    }
    if (fixedOffset != null || itemPosition != null) {
      // Scroll directly.
      await primary.scrollController.animateTo(
        fixedOffset ??
            primary.scrollController.offset +
                itemPosition!.itemLeadingEdge *
                    primary.scrollController.position.viewportDimension -
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
          // Normally a no-op: the secondary was mounted at this offset.
          secondary.scrollController
            ..nextInitialOffset = 0
            ..jumpTo(
              -direction *
                  (_screenScrollCount *
                          primary.scrollController.position.viewportDimension -
                      alignment *
                          secondary
                              .scrollController
                              .position
                              .viewportDimension),
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
      // Mount the secondary where its animation starts, so the frame after
      // the mount doesn't have to lay out two more screens of it. The
      // secondary has the same constraints as the primary, so it has the same
      // viewport dimension.
      secondary.scrollController.nextInitialOffset =
          -direction *
          (scrollAmount -
              alignment * primary.scrollController.position.viewportDimension);
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
      var swapped = false;
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
          swapped = true;
        }
        _isTransitioning = false;
        opacity.parent = const AlwaysStoppedAnimation<double>(0);
      });
      // The new primary's positions may not change again (so its notifier
      // won't fire), but the user must now see them instead of the old ones.
      if (swapped) _updatePositions();
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
    // (and every listener) that iterates the reported positions. The source is
    // sorted by index, so the filtered list is too.
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
    final notifier = widget.itemPositionsNotifier?.itemPositions;
    if (notifier != null && !samePositions(notifier.value, itemPositions)) {
      notifier.value = itemPositions;
    }
  }
}

class _ListDisplayDetails {
  _ListDisplayDetails(this.key);

  final itemPositionsNotifier = ItemPositionsNotifier();
  final scrollController = _ListScrollController();

  /// The index of the item to scroll to.
  int target = 0;

  /// The desired alignment for [target].
  ///
  /// See [ItemScrollController.jumpTo] for an explanation of alignment.
  double alignment = 0;

  /// The last [PositionedList] built for this list. Cleared whenever the
  /// [ScrollablePositionedList] widget changes.
  PositionedList? list;

  final Key key;

  /// Key of the list's center sliver, used in fixed-extent mode to read the
  /// item extent and leading padding from its render object.
  final centerKey = GlobalKey();
}

/// A [ScrollController] whose next position starts at [nextInitialOffset].
///
/// The secondary list is mounted for each long-distance scroll. Mounting it
/// straight at the offset its animation starts from, instead of at 0 and then
/// jumping, saves a frame that builds about two screens of new items.
class _ListScrollController extends ScrollController {
  _ListScrollController() : super(keepScrollOffset: false);

  /// The offset a newly attached position starts at.
  double nextInitialOffset = 0;

  @override
  double get initialScrollOffset => nextInitialOffset;
}
