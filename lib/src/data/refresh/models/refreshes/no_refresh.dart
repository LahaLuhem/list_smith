part of '../refresh.dart';

/// Pull-to-refresh off: no gesture, no indicator. Pass it to `.async`'s `refresh` to opt out.
final class const NoRefresh() extends Refresh {
  /// Creates it.
  this;

  @internal
  @override
  ScrollPhysics? scrollPhysics(ListScrollConfig scrollConfig) =>
      scrollConfig.physics ??
      // Flutter's default, which any physics list_smith passes would switch off.
      (scrollConfig.controller != null || scrollConfig.scrollDirection != .vertical
          ? null
          : const AlwaysScrollableScrollPhysics());

  @internal
  @override
  bool takesPull(PagingStatus status) => false;

  @override
  String toString() => 'NoRefresh()';
}
