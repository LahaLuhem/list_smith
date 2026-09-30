part of '../edit_transition.dart';

/// Edit transitions on. Built through [EditTransition.new].
final class AnimatedEditTransition extends EditTransition {
  /// How long a row takes to come in or go out.
  final Duration duration;

  /// Wraps a row while it animates.
  final AnimatedSwitcherTransitionBuilder transitionBuilder;

  const new _({required this.duration, required this.transitionBuilder}) : super._();

  @override
  String toString() => 'EditTransition(duration: $duration)';
}
