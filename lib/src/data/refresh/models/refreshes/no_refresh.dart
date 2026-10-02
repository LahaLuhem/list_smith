part of '../refresh.dart';

/// Pull-to-refresh off: no gesture, no indicator. Pass it to `.async`'s `refresh` to opt out.
final class const NoRefresh() extends Refresh {
  /// Creates it.
  this;

  @internal
  @override
  ScrollPhysics? scrollPhysics(ScrollPhysics? physics) => physics;

  @override
  String toString() => 'NoRefresh()';
}
