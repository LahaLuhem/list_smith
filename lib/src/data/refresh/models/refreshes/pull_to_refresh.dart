part of '../refresh.dart';

/// Pull-to-refresh on, the default: a pull past the threshold reloads the list, from the 1st page unless
/// [reload] says otherwise.
final class const PullToRefresh({
  /// Draws the indicator, built only mid-pull. Null uses the neutral default.
  final RefreshIndicatorBuilder? indicatorBuilder,

  /// The room the indicator gets along the scroll axis, which is also how far a full pull moves the list.
  /// Defaults to `64`.
  final double indicatorExtent = 64,

  /// What the pull does to the pages already loaded. [ResetToFirstPage] (the default) jumps back to the
  /// start and reloads page one, [ReloadToCurrentDepth] re-fetches every loaded page to keep depth.
  final Reload reload = const ResetToFirstPage(),
}) extends Refresh {
  /// Creates it.
  this : assert(indicatorExtent > 0, 'indicatorExtent must be positive.');

  @override
  String toString() => 'PullToRefresh()';
}
