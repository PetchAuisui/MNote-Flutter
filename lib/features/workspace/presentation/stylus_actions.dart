import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ink_page.dart';

/// What the person asked a stylus gesture (Apple Pencil double-tap or
/// squeeze) to do, as set in the system's Pencil settings.
enum StylusAction {
  /// Toggle between the eraser and the last drawing tool.
  switchEraser,

  /// Go back to the tool used before the current one.
  switchPrevious,

  /// The person turned the gesture off, or picked something we don't offer.
  ignore,
}

/// Stylus gestures that happen off the screen, delivered by the platform.
///
/// iOS sends Apple Pencil double-taps and squezes over the `mnote/stylus`
/// channel. On other platforms the stylus side button and eraser end arrive
/// as ordinary pointer events and are handled by the ink pen instead.
class StylusActions {
  StylusActions._() {
    _channel.setMethodCallHandler(_handle);
  }

  static final instance = StylusActions._();

  static const _channel = MethodChannel('mnote/stylus');

  final _actions = StreamController<StylusAction>.broadcast();

  /// Gestures, already mapped to what the person wants them to do.
  Stream<StylusAction> get actions => _actions.stream;

  /// Feeds an action as if it came from the platform (tests, and any other
  /// source of stylus gestures).
  @visibleForTesting
  void emit(StylusAction action) => _actions.add(action);

  Future<void> _handle(MethodCall call) async {
    if (call.method != 'tap' && call.method != 'squeeze') return;
    _actions.add(switch (call.arguments) {
      'switchEraser' => StylusAction.switchEraser,
      'switchPrevious' => StylusAction.switchPrevious,
      _ => StylusAction.ignore,
    });
  }
}

/// The tool to switch to after [action], given the [current] tool and the
/// one used before it. Returns `null` when nothing should change.
InkTool? toolAfterStylusAction(
  StylusAction action, {
  required InkTool current,
  required InkTool previous,
}) => switch (action) {
  StylusAction.ignore => null,
  StylusAction.switchPrevious => previous == current ? null : previous,
  StylusAction.switchEraser =>
    current == InkTool.eraser
        ? (previous == InkTool.eraser ? InkTool.pen : previous)
        : InkTool.eraser,
};
