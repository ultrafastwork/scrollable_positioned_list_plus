import 'dart:async';

import 'scroll_offset_listener.dart';

/// Internal implementation of [ScrollOffsetListener].
class ScrollOffsetNotifier implements ScrollOffsetListener {
  ScrollOffsetNotifier({this.recordProgrammaticScrolls = true});

  /// Whether scrolls triggered by the list's controllers are reported.
  final bool recordProgrammaticScrolls;

  final _streamController = StreamController<double>();

  @override
  Stream<double> get changes => _streamController.stream;

  StreamController<double> get changeController => _streamController;

  void dispose() {
    _streamController.close();
  }
}
