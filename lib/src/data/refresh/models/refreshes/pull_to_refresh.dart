part of '../refresh.dart';

/// Pull-to-refresh on (the default): a downward pull past the threshold reloads the list (from the
/// first page by default; see [reload]).
///
/// Provide [refreshBuilder] to draw a custom indicator; leave it null for list_smith's neutral one.
/// Both slots live on this case, the one that enables refresh, so neither can be set on a list whose
/// refresh is off.
final class PullToRefresh extends Refresh {
  /// Draws the pull-to-refresh indicator; null uses the neutral default.
  final RefreshBuilder? refreshBuilder;

  /// What the pull does to the pages already loaded; [ResetToFirstPage] (the default) reloads the first
  /// page and returns to the top, [ReloadToCurrentDepth] re-fetches every loaded page to keep depth.
  final Reload reload;

  /// Creates the pull-to-refresh case, optionally with a custom [refreshBuilder] and [reload] strategy.
  const PullToRefresh({this.refreshBuilder, this.reload = const ResetToFirstPage()});

  @override
  String toString() => 'PullToRefresh()';
}
