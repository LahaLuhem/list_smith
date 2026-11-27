import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '/src/data/pagination/pagination.dart';

/// The reload error on screen and how far it has grown. It grows in when a reload fails and shrinks
/// out once one lands, so the rows beside it slide instead of jumping.
///
/// Lives above the rows, so a cell scrolled away and back doesn't grow again.
@internal
final class ReloadErrorMotion({
  /// Ticks the motion.
  required final TickerProvider vsync,
}) {
  late final _sizeController = AnimationController(vsync: vsync, duration: _duration)
    ..addStatusListener(_dropOnceShrunk);
  final _shownFailureNotifier = ValueNotifier<ReloadFailure?>(null);

  /// Creates it.
  this;

  /// The failure to draw: the paging state's, or the last one while it shrinks out.
  ValueListenable<ReloadFailure?> get shownFailureListenable => _shownFailureNotifier;

  /// How far the error has grown.
  Animation<double> get sizeFactor => _sizeController;

  /// Follows the paging state's [reloadFailure], asking [isMotionAllowedGetter] only when something moves.
  void follow(ReloadFailure? reloadFailure, {required ValueGetter<bool> isMotionAllowedGetter}) {
    final isShown = reloadFailure != null;
    if (isShown) _shownFailureNotifier.value = reloadFailure;
    if (isShown ? _sizeController.isCompleted : _shownFailureNotifier.value == null) return;

    if (!isMotionAllowedGetter()) {
      _sizeController.value = isShown ? 1 : 0;

      return;
    }
    unawaited(isShown ? _sizeController.forward() : _sizeController.reverse());
  }

  /// Stops the motion, from the engine's dispose.
  void dispose() {
    _sizeController.dispose();
    _shownFailureNotifier.dispose();
  }

  void _dropOnceShrunk(AnimationStatus status) {
    if (status.isDismissed) _shownFailureNotifier.value = null;
  }

  /// About as long as the pull indicator takes to retract, so the 2 read as one motion.
  static const _duration = Duration(milliseconds: 100);
}
