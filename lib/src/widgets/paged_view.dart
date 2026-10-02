import 'package:flutter/widgets.dart';

import '/src/data/grouping/models/grouping.dart';
import '/src/data/pagination/models/paging_state.dart';
import '/src/data/pagination/typedefs/item_id_getter.dart';
import '/src/data/presentation/extensions/list_scroll_config_resolver_extension.dart';
import '/src/data/presentation/models/list_scroll_config.dart';
import '/src/data/presentation/typedefs/error_builder.dart';
import '/src/data/presentation/typedefs/item_builder.dart';
import '/src/data/presentation/typedefs/no_results_builder.dart';
import 'defaults/neutral_empty_indicator.dart';
import 'defaults/neutral_error_indicator.dart';
import 'defaults/neutral_loading_indicator.dart';
import 'defaults/neutral_no_more_items_indicator.dart';
import 'defaults/neutral_no_results_indicator.dart';
import 'keyed_paged_list_view.dart';

/// The async list, with every surface filled by our neutral default or the consumer's override.
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
  required final ListScrollConfig scroll,

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
  Widget build(BuildContext context) => KeyedPagedListView(
    state: state,
    itemBuilder: _effectiveItemBuilder(),
    itemIdGetter: itemIdGetter,
    surfaces: _surfaces(),
    onNearEnd: onNearEnd,
    separatorBuilder: separatorBuilder,
    controller: scroll.controller,
    scrollDirection: scroll.scrollDirection,
    reverse: scroll.reverse,
    physics: scroll.physics,
    padding: scroll.padding,
    scrollCacheExtent: scroll.scrollCacheExtent,
  );

  /// The item builder the rows use. The group look-back only walks the pages when grouping is on, since
  /// [Grouping.decorate] takes it as a callback.
  ItemBuilder<T> _effectiveItemBuilder() => grouping.decorate(
    itemBuilder,
    flattenItems: () => state.pages?.expand((page) => page.items) ?? const Iterable.empty(),
    axis: scroll.scrollDirection,
  );

  /// Every surface. The error ones read `state.error!`, non-null because only an error status builds
  /// them.
  PagedSurfaces _surfaces() => (
    firstPageLoading: (context) =>
        firstPageLoadingBuilder?.call(context) ?? const NeutralLoadingIndicator(),
    firstPageError: (_) =>
        _ResolvedError(error: state.error!, onRetry: onRetry, builder: firstPageErrorBuilder),
    noItemsFound: (context) => isSearchMode
        ? (noResultsBuilder?.call(context, query) ?? const NeutralNoResultsIndicator())
        : (emptyBuilder?.call(context) ?? const NeutralEmptyIndicator()),
    newPageLoading: (context) =>
        newPageLoadingBuilder?.call(context) ?? const NeutralLoadingIndicator(isCompact: true),
    newPageError: (_) => _ResolvedError(
      error: state.error!,
      onRetry: onRetry,
      builder: newPageErrorBuilder,
      isCompact: true,
    ),
    noMoreItems: (context) =>
        noMoreItemsBuilder?.call(context) ?? const NeutralNoMoreItemsIndicator(),
  );
}

/// The consumer's [ErrorBuilder] if there is one, else the neutral default.
class const _ResolvedError({
  required final Object error,
  required final VoidCallback onRetry,
  final ErrorBuilder? builder,
  final bool isCompact = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final errorBuilder = builder;

    return errorBuilder != null
        ? errorBuilder(context, error, onRetry)
        : NeutralErrorIndicator(error: error, onRetry: onRetry, isCompact: isCompact);
  }
}
