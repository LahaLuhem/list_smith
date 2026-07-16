import 'package:flutter/widgets.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '/src/data/grouping/models/grouping.dart';
import '/src/data/grouping/utils/grouping_resolver.dart';
import '/src/data/presentation/models/list_scroll_config.dart';
import '/src/data/presentation/typedefs/error_builder.dart';
import '/src/data/presentation/typedefs/item_builder.dart';
import '/src/data/presentation/typedefs/no_results_builder.dart';
import 'defaults/neutral_empty_indicator.dart';
import 'defaults/neutral_error_indicator.dart';
import 'defaults/neutral_loading_indicator.dart';
import 'defaults/neutral_no_more_items_indicator.dart';
import 'defaults/neutral_no_results_indicator.dart';
import 'grouped_item.dart';

/// Wraps ISP's [PagedListView], filling every delegate slot with list_smith's neutral defaults
/// (or the consumer's overrides) so no Material surface leaks through, and bridging the bare error
/// slots to our [ErrorBuilder] contract.
///
/// Internal: built by the shell inside a [PagingListener], where the paging [state] and its [fetchNextPage]
/// callback are in scope.
class PagedView<T extends Object> extends StatelessWidget {
  /// The current paging state, driving which surface renders.
  final PagingState<int, T> state;

  /// Requests the next page; also used as the retry action on error surfaces.
  final VoidCallback fetchNextPage;

  /// Builds each item.
  final ItemBuilder<T> itemBuilder;

  /// Splits the visible items into sections; [NoGrouping] (the default) renders a flat list.
  final Grouping<T> grouping;

  /// Scroll and layout configuration.
  final ListScrollConfig scroll;

  /// Whether the current results are a search: picks the no-results surface over the empty one.
  final bool isSearchMode;

  /// The committed query, handed to [noResultsBuilder] when [isSearchMode] and nothing matched.
  final String query;

  /// Builds separators between items; null for none.
  final IndexedWidgetBuilder? separatorBuilder;

  /// Overrides for the neutral default surfaces; null falls back to the default.
  final WidgetBuilder? firstPageLoadingBuilder;

  /// See [firstPageLoadingBuilder].
  final WidgetBuilder? newPageLoadingBuilder;

  /// See [firstPageLoadingBuilder].
  final ErrorBuilder? firstPageErrorBuilder;

  /// See [firstPageLoadingBuilder].
  final ErrorBuilder? newPageErrorBuilder;

  /// See [firstPageLoadingBuilder]. Shown when the source has no items in normal mode.
  final WidgetBuilder? emptyBuilder;

  /// See [firstPageLoadingBuilder]. Shown when a search yields nothing in search mode.
  final NoResultsBuilder? noResultsBuilder;

  /// See [firstPageLoadingBuilder].
  final WidgetBuilder? noMoreItemsBuilder;

  /// Creates the paged view around the current [state].
  const PagedView({
    required this.state,
    required this.fetchNextPage,
    required this.itemBuilder,
    required this.grouping,
    required this.scroll,
    required this.isSearchMode,
    required this.query,
    this.separatorBuilder,
    this.firstPageLoadingBuilder,
    this.newPageLoadingBuilder,
    this.firstPageErrorBuilder,
    this.newPageErrorBuilder,
    this.emptyBuilder,
    this.noResultsBuilder,
    this.noMoreItemsBuilder,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final builderDelegate = _buildDelegate();

    return separatorBuilder != null
        ? PagedListView.separated(
            state: state,
            fetchNextPage: fetchNextPage,
            builderDelegate: builderDelegate,
            separatorBuilder: separatorBuilder!,
            scrollController: scroll.controller,
            scrollDirection: scroll.scrollDirection,
            reverse: scroll.reverse,
            physics: scroll.physics,
            padding: scroll.padding,
            cacheExtent: scroll.cacheExtent,
          )
        : PagedListView(
            state: state,
            fetchNextPage: fetchNextPage,
            builderDelegate: builderDelegate,
            scrollController: scroll.controller,
            scrollDirection: scroll.scrollDirection,
            reverse: scroll.reverse,
            physics: scroll.physics,
            padding: scroll.padding,
            cacheExtent: scroll.cacheExtent,
          );
  }

  /// The item builder handed to ISP: [itemBuilder] unchanged when the list is not grouped, otherwise
  /// one that prefixes each group's first item with its header. The loaded pages are flattened for the
  /// group look-back (and the debug contiguity check) only when grouping is active.
  ItemBuilder<T> _effectiveItemBuilder() {
    final grouping = this.grouping;
    if (grouping is! KeyedGrouping<T>) return itemBuilder;

    final flatItems = state.pages?.expand((page) => page).toList(growable: false) ?? <T>[];
    assert(
      groupsAreContiguous(flatItems, grouping.groupOf),
      'Grouping on an async list needs each page ordered by group key; a group key reappeared '
      'after its section ended, so its header would fragment.',
    );

    return groupedItemBuilder(grouping, itemBuilder, scroll.scrollDirection, flatItems);
  }

  /// Fills every ISP delegate slot with the neutral defaults or the consumer's overrides. The error
  /// slots read `state.error!`, non-null because ISP only builds an error indicator when an error is
  /// present.
  PagedChildBuilderDelegate<T> _buildDelegate() => PagedChildBuilderDelegate<T>(
    itemBuilder: _effectiveItemBuilder(),
    firstPageProgressIndicatorBuilder: (context) =>
        firstPageLoadingBuilder?.call(context) ?? const NeutralLoadingIndicator(),
    newPageProgressIndicatorBuilder: (context) =>
        newPageLoadingBuilder?.call(context) ?? const NeutralLoadingIndicator(compact: true),
    firstPageErrorIndicatorBuilder: (_) =>
        _ResolvedError(error: state.error!, onRetry: fetchNextPage, builder: firstPageErrorBuilder),
    newPageErrorIndicatorBuilder: (_) => _ResolvedError(
      error: state.error!,
      onRetry: fetchNextPage,
      builder: newPageErrorBuilder,
      compact: true,
    ),
    noItemsFoundIndicatorBuilder: (context) => isSearchMode
        ? (noResultsBuilder?.call(context, query) ?? const NeutralNoResultsIndicator())
        : (emptyBuilder?.call(context) ?? const NeutralEmptyIndicator()),
    noMoreItemsIndicatorBuilder: (context) =>
        noMoreItemsBuilder?.call(context) ?? const NeutralNoMoreItemsIndicator(),
  );
}

/// Picks the consumer's [ErrorBuilder] if given, else the neutral default, wiring both to the same
/// `error` and `onRetry`.
class _ResolvedError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  final ErrorBuilder? builder;
  final bool compact;

  const _ResolvedError({
    required this.error,
    required this.onRetry,
    this.builder,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final errorBuilder = builder;

    return errorBuilder != null
        ? errorBuilder(context, error, onRetry)
        : NeutralErrorIndicator(error: error, onRetry: onRetry, compact: compact);
  }
}
