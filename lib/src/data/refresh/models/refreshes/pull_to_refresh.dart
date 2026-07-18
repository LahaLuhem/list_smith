part of '../refresh.dart';

/// Pull-to-refresh on (the default): a downward pull past the threshold reloads the list from its
/// first page.
///
/// Provide [refreshBuilder] to draw a custom indicator; leave it null for list_smith's neutral one.
/// The builder lives on this case, the one that enables refresh, so it cannot be set on a list whose
/// refresh is off.
final class PullToRefresh extends Refresh {
  /// Draws the pull-to-refresh indicator; null uses the neutral default.
  final RefreshBuilder? refreshBuilder;

  /// Creates the pull-to-refresh case, optionally with a custom [refreshBuilder].
  const PullToRefresh({this.refreshBuilder});

  @override
  String toString() => 'PullToRefresh()';
}
