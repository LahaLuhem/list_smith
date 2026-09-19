/// @docImport 'list_smith_controller.dart';
library;

import 'package:meta/meta.dart';

/// What a [ListSmithController] drives: the engine's own entry points, one per intent.
///
/// The engine implements it and attaches itself, so the handle and the gesture can't drift apart.
@internal
abstract interface class ListSmithControllerHost {
  /// See [ListSmithController.refresh].
  Future<void> refresh();

  /// See [ListSmithController.invalidate].
  Future<void> invalidate();

  /// See [ListSmithController.reset].
  Future<void> reset();
}
