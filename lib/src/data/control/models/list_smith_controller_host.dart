/// @docImport 'list_smith_controller.dart';
library;

import 'package:meta/meta.dart';

/// What a [ListSmithController] drives: the engine's own entry points, one per intent.
///
/// The engine implements it and attaches itself, so the handle and the gesture can't drift apart.
@internal
abstract interface class ListSmithControllerHost<T extends Object>._() {
  /// See [ListSmithController.refresh].
  Future<void> refresh();

  /// See [ListSmithController.invalidate].
  Future<void> invalidate();

  /// See [ListSmithController.reset].
  Future<void> reset();

  /// See [ListSmithController.upsert].
  void upsert(T item);

  /// See [ListSmithController.remove].
  void remove(T item);

  /// See [ListSmithController.upsertAsync].
  Future<void> upsertAsync(
    T draft, {
    required Future<T> commit,
    void Function(Exception exception)? onFailure,
  });

  /// See [ListSmithController.removeAsync].
  Future<void> removeAsync(
    T item, {
    required Future<void> commit,
    void Function(Exception exception)? onFailure,
  });
}
