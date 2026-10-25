import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '/src/data/grouping/grouping.dart';
import '/src/data/pagination/pagination.dart';
import '/src/data/presentation/presentation.dart';
import '/src/data/refresh/refresh.dart';
import 'defaults/defaults.dart';
import 'keyed_list_view.dart';

/// The async list, with every surface filled by our neutral default or the consumer's override.
@internal
class const PagedView<T extends Object>({
  /// Drives which surface renders.
  required final PagingState<T> state,

  /// Asks for the next page, from a row near the end.
  required final VoidCallback onNearEnd,

  /// Asks again for the page that failed, from an error surface's retry.
  required final VoidCallback onRetry,

  /// Builds each item.
  required final ItemBuilder<T> itemBuilder,

  /// Keys each row by its item.
  required final ItemIdGetter<T> itemIdGetter,

  /// Splits the visible items into sections. [NoGrouping] (the default) renders a flat list.
  required final Grouping<T> grouping,

  /// Scroll and layout configuration.
  required final ListScrollConfig scrollConfig,

  /// Whether the list takes a pull, which decides the physics it scrolls with.
  required final Refresh refresh,

  /// Whether a surface shows instead of the rows, read as a drag goes.
  required final ValueGetter<bool> showsSurfaceGetter,

  /// Whether a pull may start on what shows, read as a drag goes.
  required final ValueGetter<bool> takesPullGetter,

  /// How far a pull pushes the list now.
  required final ValueListenable<double> pullExtentListenable,

  /// Whether the row on top holds still when rows above it change, or a pull's room does.
  required final bool shouldKeepPosition,

  /// Whether the current results are a search: picks the no-results surface over the empty one.
  required final bool isSearchMode,

  /// The committed query, handed to [noResultsBuilder] when [isSearchMode] and nothing matched.
  required final String query,

  /// Builds separators between items. Null for none.
  final IndexedWidgetBuilder? separatorBuilder,

  /// Overrides for the neutral default surfaces. Null keeps the default.
  final WidgetBuilder? firstPageLoadingBuilder,

  /// See [firstPageLoadingBuilder].
  final WidgetBuilder? newPageLoadingBuilder,

  /// See [firstPageLoadingBuilder].
  final ErrorBuilder? firstPageErrorBuilder,

  /// See [firstPageLoadingBuilder].
  final ErrorBuilder? newPageErrorBuilder,

  /// See [firstPageLoadingBuilder]. Shown when the source has no items in normal mode.
  final WidgetBuilder? emptyBuilder,

  /// See [firstPageLoadingBuilder]. Shown when a search yields nothing in search mode.
  final NoResultsBuilder? noResultsBuilder,

  /// See [firstPageLoadingBuilder].
  final WidgetBuilder? noMoreItemsBuilder,
  super.key,
}) extends StatelessWidget {
  /// Creates it.
  this;

  @override
  Widget build(BuildContext context) {
    final status = state.status;
    // The error surfaces read `state.exception!`, non-null because only an error status builds them.
    final surfaceWidget = switch (status) {
      .loadingFirstPage =>
        firstPageLoadingBuilder?.call(context) ?? const NeutralLoadingIndicator(),
      .firstPageError => _ResolvedError(
        exception: state.exception!,
        onRetry: onRetry,
        builder: firstPageErrorBuilder,
      ),
      .noItemsFound when isSearchMode =>
        noResultsBuilder?.call(context, query) ?? const NeutralNoResultsIndicator(),
      .noItemsFound => emptyBuilder?.call(context) ?? const NeutralEmptyIndicator(),
      .ongoing || .subsequentPageError || .completed => null,
    };

    return KeyedListView(
      // A view, not a copy. Pages never change once built.
      pagedItems: UnmodifiableListView((state.pages ?? const []).map((page) => page.items)),
      itemBuilder: itemBuilder,
      itemIdGetter: itemIdGetter,
      grouping: grouping,
      // One shape whatever the footer shows: the end, a new page loading, or its error.
      footerBuilder: switch (status) {
        .subsequentPageError => (_) => _ResolvedError(
          exception: state.exception!,
          onRetry: onRetry,
          builder: newPageErrorBuilder,
          isCompact: true,
        ),
        .completed => noMoreItemsBuilder ?? (_) => const NeutralNoMoreItemsIndicator(),
        _ => newPageLoadingBuilder ?? (_) => const NeutralLoadingIndicator(isCompact: true),
      },
      pullExtentListenable: pullExtentListenable,
      shouldKeepPosition: shouldKeepPosition,
      // Keyed by status, so one surface replacing another starts fresh.
      surface: surfaceWidget == null
          ? null
          : KeyedSubtree(key: ValueKey(status), child: surfaceWidget),
      // Only an ongoing list asks for more, so a failed page waits for Retry.
      onNearEnd: status == .ongoing ? onNearEnd : null,
      separatorBuilder: separatorBuilder,
      controller: scrollConfig.controller,
      scrollDirection: scrollConfig.scrollDirection,
      reverse: scrollConfig.reverse,
      physics: _SurfaceDragPhysics(
        showsSurfaceGetter: showsSurfaceGetter,
        takesPullGetter: takesPullGetter,
        parent: refresh.scrollPhysics(scrollConfig),
      ),
      padding: scrollConfig.padding,
      scrollCacheExtent: scrollConfig.scrollCacheExtent,
    );
  }
}

/// The consumer's [ErrorBuilder] if there is one, else the neutral default.
class const _ResolvedError({
  required final Exception exception,
  required final VoidCallback onRetry,
  final ErrorBuilder? builder,
  final bool isCompact = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final errorBuilder = builder;

    return errorBuilder != null
        ? errorBuilder(context, exception, onRetry)
        : NeutralErrorIndicator(exception: exception, onRetry: onRetry, isCompact: isCompact);
  }
}

/// While a surface shows, the list moves past its ends only into a pull [takesPullGetter] allows.
/// Both getters are read live, since the list keeps the 1st physics it gets.
final class const _SurfaceDragPhysics({
  required final ValueGetter<bool> showsSurfaceGetter,
  required final ValueGetter<bool> takesPullGetter,
  super.parent,
}) extends ScrollPhysics {
  @override
  _SurfaceDragPhysics applyTo(ScrollPhysics? ancestor) => _SurfaceDragPhysics(
    showsSurfaceGetter: showsSurfaceGetter,
    takesPullGetter: takesPullGetter,
    parent: buildParent(ancestor),
  );

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    final parentAdjustedOffset = super.applyPhysicsToUserOffset(position, offset);
    if (!showsSurfaceGetter()) return parentAdjustedOffset;

    final currentScrollOffset = position.pixels;
    // Never further out than now, so a pull the list changes under stops instead of snapping back.
    final minScrollOffset = takesPullGetter()
        ? double.negativeInfinity
        : math.min(position.minScrollExtent, currentScrollOffset);
    final maxScrollOffset = math.max(position.maxScrollExtent, currentScrollOffset);

    return currentScrollOffset -
        (currentScrollOffset - parentAdjustedOffset).clamp(minScrollOffset, maxScrollOffset);
  }
}
