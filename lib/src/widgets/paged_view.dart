import 'package:flutter/widgets.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../data/presentation/error_builder.dart';
import '../data/presentation/item_builder.dart';
import '../data/presentation/list_scroll_config.dart';
import '../data/presentation/no_results_builder.dart';
import 'defaults/neutral_empty_indicator.dart';
import 'defaults/neutral_error_indicator.dart';
import 'defaults/neutral_loading_indicator.dart';
import 'defaults/neutral_no_more_items_indicator.dart';
import 'defaults/neutral_no_results_indicator.dart';

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
    // The error slots read `state.error!`: ISP only builds an error indicator when an error is present,
    // so it is non-null at that point.
    final delegate = PagedChildBuilderDelegate<T>(
      itemBuilder: itemBuilder,
      firstPageProgressIndicatorBuilder: (context) =>
          firstPageLoadingBuilder?.call(context) ?? const NeutralLoadingIndicator(),
      newPageProgressIndicatorBuilder: (context) =>
          newPageLoadingBuilder?.call(context) ?? const NeutralLoadingIndicator(compact: true),
      firstPageErrorIndicatorBuilder: (_) => _ResolvedError(
        error: state.error!,
        onRetry: fetchNextPage,
        builder: firstPageErrorBuilder,
      ),
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

    final separatorBuilder = this.separatorBuilder;

    return separatorBuilder != null
        ? PagedListView<int, T>.separated(
            state: state,
            fetchNextPage: fetchNextPage,
            builderDelegate: delegate,
            separatorBuilder: separatorBuilder,
            scrollController: scroll.controller,
            scrollDirection: scroll.scrollDirection,
            reverse: scroll.reverse,
            physics: scroll.physics,
            padding: scroll.padding,
            cacheExtent: scroll.cacheExtent,
          )
        : PagedListView<int, T>(
            state: state,
            fetchNextPage: fetchNextPage,
            builderDelegate: delegate,
            scrollController: scroll.controller,
            scrollDirection: scroll.scrollDirection,
            reverse: scroll.reverse,
            physics: scroll.physics,
            padding: scroll.padding,
            cacheExtent: scroll.cacheExtent,
          );
  }
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
