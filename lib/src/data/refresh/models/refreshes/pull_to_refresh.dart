part of '../refresh.dart';

/// Pull-to-refresh on (the default): a downward pull past the threshold reloads the list, from the
/// first page by default. See [reload].
///
/// [refreshBuilder] draws a custom indicator, null keeps the neutral one. Both slots live here, on
/// the case that turns refresh on, so neither can be set on a list whose refresh is off.
final class PullToRefresh extends Refresh {
  /// Draws the pull-to-refresh indicator. Null uses the neutral default.
  final RefreshBuilder? refreshBuilder;

  /// What the pull does to the pages already loaded. [ResetToFirstPage] (the default) snaps to the
  /// top and reloads page one, [ReloadToCurrentDepth] re-fetches every loaded page to keep depth.
  final Reload reload;

  /// Creates the pull-to-refresh case, optionally with a custom [refreshBuilder] and [reload] strategy.
  const new({this.refreshBuilder, this.reload = const ResetToFirstPage()});

  @override
  String toString() => 'PullToRefresh()';
}
