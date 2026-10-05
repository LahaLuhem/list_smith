part of '../refresh.dart';

/// Pull-to-refresh off: no gesture, no indicator. Pass it to `.async`'s `refresh` to opt out.
final class const NoRefresh() extends Refresh {
  /// Creates it.
  this;

  @internal
  @override
  ScrollPhysics? scrollPhysics(ScrollPhysics? physics) => physics;

  @internal
  @override
  bool takesPull(PagingStatus status) => false;

  @override
  String toString() => 'NoRefresh()';
}
