part of '../edit_transition.dart';

/// No edit transitions: an edit shows at once. The default.
final class NoEditTransition extends EditTransition {
  /// Creates it.
  const new() : super._();

  @override
  String toString() => 'NoEditTransition()';
}
