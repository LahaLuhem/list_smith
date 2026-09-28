part of '../refresh.dart';

/// Pull-to-refresh on, the default: a pull past the threshold reloads the list, from the 1st page unless
/// [reload] says otherwise.
final class PullToRefresh extends Refresh {
  /// Draws the indicator, built only mid-pull. Null uses the neutral default.
  final RefreshIndicatorBuilder? indicatorBuilder;

  /// What the pull does to the pages already loaded. [ResetToFirstPage] (the default) snaps to the top
  /// and reloads page one, [ReloadToCurrentDepth] re-fetches every loaded page to keep depth.
  final Reload reload;

  /// Creates it.
  const new({this.indicatorBuilder, this.reload = const ResetToFirstPage()});

  @override
  String toString() => 'PullToRefresh()';
}
