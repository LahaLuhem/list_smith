part of '../edit_transition.dart';

/// Edit transitions on. Built through [EditTransition.new].
final class const AnimatedEditTransition._({
  /// How long a row takes to come in or go out.
  required final Duration duration,

  /// Wraps a row while it animates.
  required final AnimatedSwitcherTransitionBuilder transitionBuilder,
}) extends EditTransition {
  /// Creates it.
  this : super._();

  @override
  String toString() => 'EditTransition(duration: $duration)';
}
