/// @docImport '../data/search/search_cache_policy.dart';
/// @docImport 'list_smith.dart';
library;

import 'package:flutter/widgets.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../data/pagination/pagination_end_policy.dart';
import '../data/pagination/pagination_end_policy_resolver.dart';
import '../data/presentation/async_list_surfaces.dart';
import '../data/presentation/item_builder.dart';
import '../data/presentation/list_scroll_config.dart';
import '../data/presentation/no_results_builder.dart';
import '../data/search/search_cache_policy_resolver.dart';
import '../data/source/list_source.dart';
import '../utils/query_debouncer.dart';
import 'paged_view.dart';
import 'refresh_binding.dart';

/// The async engine behind [ListSmith.async]: owns the paging controller lifecycle, wires
/// pull-to-refresh, and (when the source supports search) drives a two-view normal ↔ search mode on
/// the one controller.
///
/// Unexported. [ListSmith] builds one of these for an [AsyncSource]. The fetch closure reads the
/// debounced committed query: empty means normal mode ([AsyncSource.fetchPage]), non-empty means
/// search mode ([AsyncSource.searchFetchPage]). A committed-query change runs the
/// [AsyncSource.searchCachePolicy] against the controller. Defaults are resolved by [ListSmith.async];
/// this widget re-declares none.
class AsyncListView<T extends Object> extends StatefulWidget {
  /// The async, paginated source: its fetchers, end policy, and search cache policy.
  final AsyncSource<T> source;

  /// Builds the widget for each item.
  final ItemBuilder<T> itemBuilder;

  /// Builds the separator between items; null for no separators.
  final IndexedWidgetBuilder? separatorBuilder;

  /// Whether pull-to-refresh is enabled.
  final bool pullToRefresh;

  /// The current search query; empty drives normal mode, non-empty drives search mode.
  final String query;

  /// Minimum trimmed query length before a search runs; below it the query counts as empty.
  final int minSearchLength;

  /// How long to wait after [query] changes before it takes effect; [Duration.zero] is immediate.
  final Duration searchDebounce;

  /// Builds the surface shown when the source yields no items; null uses the neutral default.
  final WidgetBuilder? emptyBuilder;

  /// Builds the surface shown when a search matches nothing; null uses the neutral default.
  final NoResultsBuilder? noResultsBuilder;

  /// The async-only override surfaces (page loading and error, end-of-list footer, refresh indicator).
  final AsyncListSurfaces surfaces;

  /// Scroll and layout configuration for the underlying scrollable.
  final ListScrollConfig scroll;

  /// Creates the async paged list around an [AsyncSource].
  const AsyncListView({
    required this.source,
    required this.itemBuilder,
    required this.pullToRefresh,
    required this.query,
    required this.minSearchLength,
    required this.searchDebounce,
    required this.surfaces,
    required this.scroll,
    this.separatorBuilder,
    this.emptyBuilder,
    this.noResultsBuilder,
    super.key,
  });

  @override
  State<AsyncListView<T>> createState() => _AsyncListViewState<T>();
}

class _AsyncListViewState<T extends Object> extends State<AsyncListView<T>> {
  late final _debouncer = QueryDebouncer(onCommitted: _onQueryCommitted);
  late final _controller = PagingController<int, T>(
    getNextPageKey: (state) => _nextPageKey(state, widget.source.endPolicy),
    fetchPage: _fetchPage,
  );

  /// The normal-mode paging state kept aside while searching, for [KeepCachePolicy].
  PagingState<int, T>? _normalSnapshot;

  /// Whether the controller currently reflects search results (drives the empty/no-results surface).
  late final ValueNotifier<bool> _searchModeNotifier;

  @override
  void initState() {
    super.initState();

    _debouncer.seed(widget.query);
    _searchModeNotifier = ValueNotifier(_isSearchQuery(_debouncer.committedQuery));
  }

  @override
  void didUpdateWidget(AsyncListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.query != oldWidget.query) _debouncer.schedule(widget.query, widget.searchDebounce);
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _controller.dispose();
    _searchModeNotifier.dispose();

    super.dispose();
  }

  bool _isSearchQuery(String query) => query.isNotEmpty && widget.source.supportsSearch;

  Future<List<T>> _fetchPage(int pageKey) async {
    final source = widget.source;
    final committedQuery = _debouncer.committedQuery;
    final page = _isSearchQuery(committedQuery)
        ? await source.searchFetchPage!(committedQuery, pageKey, source.pageSize)
        : await source.fetchPage(pageKey, source.pageSize);

    return page.toList(growable: false);
  }

  void _onQueryCommitted(String committedQuery) {
    final isSearchMode = _isSearchQuery(committedQuery);
    final action = widget.source.searchCachePolicy.actionFor(
      wasSearching: _searchModeNotifier.value,
      isSearching: isSearchMode,
    );

    _searchModeNotifier.value = isSearchMode;
    _applyCacheAction(action);
  }

  void _applyCacheAction(CacheAction action) {
    switch ((action, _normalSnapshot)) {
      case (.restoreNormal, final snapshot?):
        _controller.value = snapshot;
        _normalSnapshot = null;
      case (.snapshotThenRefresh, _):
        _normalSnapshot = _controller.value;
        _controller.refresh();
      case (.refresh, _) || (.restoreNormal, null):
        _controller.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = widget.surfaces;

    final list = PagingListener(
      controller: _controller,
      builder: (_, state, fetchNextPage) => ValueListenableBuilder(
        valueListenable: _searchModeNotifier,
        builder: (_, isSearchMode, _) => PagedView(
          state: state,
          fetchNextPage: fetchNextPage,
          itemBuilder: widget.itemBuilder,
          scroll: widget.scroll,
          isSearchMode: isSearchMode,
          query: _debouncer.committedQuery,
          separatorBuilder: widget.separatorBuilder,
          firstPageLoadingBuilder: surfaces.firstPageLoadingBuilder,
          newPageLoadingBuilder: surfaces.newPageLoadingBuilder,
          firstPageErrorBuilder: surfaces.firstPageErrorBuilder,
          newPageErrorBuilder: surfaces.newPageErrorBuilder,
          emptyBuilder: widget.emptyBuilder,
          noResultsBuilder: widget.noResultsBuilder,
          noMoreItemsBuilder: surfaces.noMoreItemsBuilder,
        ),
      ),
    );

    if (!widget.pullToRefresh) return list;

    return RefreshBinding(
      onRefresh: _onRefresh,
      refreshBuilder: surfaces.refreshBuilder,
      child: list,
    );
  }

  Future<void> _onRefresh() => Future.sync(_controller.refresh);
}

/// Computes the next 0-based page key for [state], or `null` once [endPolicy] reports the end.
/// Keys are the page count so far, so they stay 0-based and sequential.
int? _nextPageKey<T extends Object>(PagingState<int, T> state, PaginationEndPolicy endPolicy) {
  final pages = state.pages;
  if (pages == null || pages.isEmpty) return 0;

  final pageItemCounts = pages.map((page) => page.length);
  if (endPolicy.hasReachedEnd(pageItemCounts.toList(growable: false))) return null;

  return pages.length;
}
