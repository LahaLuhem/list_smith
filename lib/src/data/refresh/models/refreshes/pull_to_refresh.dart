part of '../refresh.dart';

/// Pull-to-refresh on, the default: a pull past the threshold reloads the list, from the 1st page unless
/// [reload] says otherwise. Short content takes a pull too, whatever the scroll setup.
final class const PullToRefresh({
  /// Draws the indicator, built only mid-pull. Null uses the neutral default.
  final RefreshIndicatorBuilder? indicatorBuilder,

  /// The room the indicator gets along the scroll axis, which is also how far a full pull moves the list.
  /// Defaults to `64`.
  final double indicatorExtent = 64,

  /// What the pull does to the pages already loaded. [ResetToFirstPage] (the default) jumps back to the
  /// start and reloads page one, [ReloadToCurrentDepth] re-fetches every loaded page to keep depth.
  final Reload reload = const ResetToFirstPage(),

  /// The surfaces shown instead of the rows that a pull still refreshes. The rows always take one and the
  /// loader never does. Defaults to both, so a pull retries an error or asks an empty list again.
  final Set<PullableSurface> pullableSurfaces = const {.error, .empty},
}) extends Refresh {
  /// Creates it.
  this : assert(indicatorExtent > 0, 'indicatorExtent must be positive.');

  /// Always-scrollable, so short content can still be pulled. Below the app's [physics] in the chain, so
  /// a [NeverScrollableScrollPhysics] there still wins.
  @internal
  @override
  ScrollPhysics scrollPhysics(ScrollPhysics? physics) =>
      physics?.applyTo(const AlwaysScrollableScrollPhysics()) ??
      const AlwaysScrollableScrollPhysics();

  @override
  String toString() => 'PullToRefresh()';
}
