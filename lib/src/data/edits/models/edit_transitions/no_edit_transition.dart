part of '../edit_transition.dart';

/// No edit transitions: an edit shows at once. The default.
final class const NoEditTransition() extends EditTransition {
  /// Creates it.
  this : super._();

  @override
  String toString() => 'NoEditTransition()';
}
