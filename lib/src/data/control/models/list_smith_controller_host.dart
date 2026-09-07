/// @docImport 'list_smith_controller.dart';
library;

import 'package:meta/meta.dart';

/// What a [ListSmithController] drives: the engine's own entry points, one per intent.
///
/// The engine implements it and attaches itself, so the handle can't grow a second implementation
/// that drifts from what the gesture runs. Internal: consumers hold the controller, never the engine.
@internal
abstract interface class ListSmithControllerHost {
  /// Reloads exactly as a pull would. The contract is [ListSmithController.refresh]'s.
  Future<void> refresh();

  /// Re-reads every loaded page in place. The contract is [ListSmithController.invalidate]'s.
  Future<void> invalidate();

  /// Starts the list over from its first page. The contract is [ListSmithController.reset]'s.
  Future<void> reset();
}
