/// @docImport '/src/data/search/models/search_cache_policy.dart';
/// @docImport 'list_smith.dart';
library;

import 'package:flutter/widgets.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '/src/data/grouping/models/grouping.dart';
import '/src/data/observer/models/list_smith_observer.dart';
import '/src/data/pagination/models/end_context.dart';
import '/src/data/presentation/models/async_list_surfaces.dart';
import '/src/data/presentation/models/list_scroll_config.dart';
import '/src/data/presentation/typedefs/item_builder.dart';
import '/src/data/presentation/typedefs/no_results_builder.dart';
import '/src/data/refresh/models/refresh.dart';
import '/src/data/search/enums/cache_action.dart';
import '/src/data/search/extensions/search_cache_policy_resolver_extension.dart';
import '/src/data/search/models/search.dart';
import '/src/data/source/list_source.dart';
import '/src/utils/query_debouncer.dart';
import 'paged_view.dart';
import 'refresh_binding.dart';

/// The async engine behind [ListSmith.async]: owns the paging controller lifecycle, wires
/// pull-to-refresh, and (when the source supports search) drives a two-view normal ↔ search mode on
/// the one controller.
///
/// Unexported. [ListSmith] builds one of these for an [AsyncSource]. The fetch closure reads the
/// debounced committed query: empty means normal mode ([AsyncSource.fetchPage]), non-empty means
/// search mode (the [AsyncSearch] fetcher). A committed-query change runs that search's cache policy
/// against the controller. Defaults are resolved by [ListSmith.async]; this widget re-declares none.
class AsyncListView<T extends Object> extends StatefulWidget {
  /// The async, paginated source: its fetchers, end policy, and search cache policy.
  final AsyncSource<T> source;

  /// Builds the widget for each item.
  final ItemBuilder<T> itemBuilder;

  /// Splits the visible items into sections; [NoGrouping] (the default) renders a flat list.
  final Grouping<T> grouping;

  /// Builds the separator between items; null for no separators.
  final IndexedWidgetBuilder? separatorBuilder;

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

  /// Optional lifecycle observer for logging or telemetry; null is silent.
  final ListSmithObserver? observer;

  /// Creates the async paged list around an [AsyncSource].
  const AsyncListView({
    required this.source,
    required this.itemBuilder,
    required this.grouping,
    required this.query,
    required this.minSearchLength,
    required this.searchDebounce,
    required this.surfaces,
    required this.scroll,
    this.separatorBuilder,
    this.emptyBuilder,
    this.noResultsBuilder,
    this.observer,
    super.key,
  });

  @override
  State<AsyncListView<T>> createState() => _AsyncListViewState<T>();
}

class _AsyncListViewState<T extends Object> extends State<AsyncListView<T>> {
  late final _debouncer = QueryDebouncer(onCommitted: _onQueryCommitted);
  late final _controller = PagingController<int, T>(
    getNextPageKey: _nextPageKey,
    fetchPage: _fetchPage,
  );

  /// The normal-mode paging state (with its end signal) kept aside while searching, for
  /// [KeepCachePolicy].
  ({PagingState<int, T> state, Object? signal})? _normalSnapshot;

  /// The end signal from the current stream's most recent fetch, fed to the end policy via
  /// [EndContext.lastPageSignal]. Owned here because it is not derivable from the paging state: it
  /// resets on refresh and snapshots with [_normalSnapshot] across a search toggle, so a signal-based
  /// policy stays correct in either mode. Null until a signal-reporting fetcher sets it.
  Object? _lastPageSignal;

  /// Memo for [_dedupedForDisplay]: the last raw state seen paired with the view derived from it, or
  /// null before the first de-dup. Keyed on paging-state identity; the controller hands out the same
  /// [PagingState] instance until the data changes, so a rebuild that leaves it untouched (an ancestor
  /// rebuild, e.g. a keystroke before the search debounce commits) reuses the view instead of
  /// re-running the O(loaded) pass. Kept as one cell so the pair can't drift out of sync.
  ({PagingState<int, T> raw, PagingState<int, T> display})? _displayMemo;

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
    final search = source.search;
    final committedQuery = _debouncer.committedQuery;
    final isSearchMode = _isSearchQuery(committedQuery);
    final previousSignal = _lastPageSignal;

    try {
      final (items, signal) = switch (search) {
        final AsyncSearch<T> s when isSearchMode => await s.fetchPage(
          committedQuery,
          pageKey,
          source.pageSize,
          previousSignal,
        ),
        AsyncSearch<T>() ||
        NoSearch() => await source.fetchPage(pageKey, source.pageSize, previousSignal),
      };
      _lastPageSignal = signal;

      final pageItems = items.toList(growable: false);
      widget.observer?.onPageLoaded(pageKey, pageItems.length, isSearchMode: isSearchMode);

      return pageItems;
    } on Object catch (error, stackTrace) {
      widget.observer?.onError(error, stackTrace);

      rethrow;
    }
  }

  /// The next 0-based page key for [state], or `null` once the end policy reports the end.
  ///
  /// Keys are the page count so far, so they stay 0-based and sequential. The end decision is the
  /// injected [AsyncSource.endPolicy] applied to an [EndContext] rebuilt from the pages loaded so far.
  int? _nextPageKey(PagingState<int, T> state) {
    final pages = state.pages;
    if (pages == null || pages.isEmpty) return 0;

    final context = EndContext(
      pageItemCounts: pages.map((page) => page.length).toList(growable: false),
      pageSize: widget.source.pageSize,
      lastPageSignal: _lastPageSignal,
    );

    return widget.source.endPolicy.hasReachedEnd(context) ? null : pages.length;
  }

  /// A display-only copy of [state] with items whose [AsyncSource.itemId] key already appeared earlier
  /// dropped, so overlapping pages don't render an item twice. A null `itemId` disables it (the pager
  /// itself never de-duplicates).
  ///
  /// De-dup is a display concern and stays off the controller's own pages: those stay raw, so
  /// [_nextPageKey] feeds the end policy what the backend actually returned and a fully-duplicate page
  /// is not mistaken for an empty end-of-data one. ISP's `PagingState.filterItems` is built for
  /// exactly this ("use the returned value as computed state only"): it walks the pages in flattened
  /// order, so the `seen` set threads across them and the predicate keeps only each key's first
  /// sighting. We lean on that ordered pass rather than hand-rolling the fold; swap it for an explicit
  /// one if the rule ever outgrows a per-item predicate.
  ///
  /// The pass is O(loaded items) and runs on each state change, so it is memoised on state identity
  /// ([_displayMemo]): a rebuild that doesn't touch the state reuses the last view for free. Only
  /// opt-in (a non-null `itemId`) pays anything; without it this returns the state untouched.
  PagingState<int, T> _dedupedForDisplay(PagingState<int, T> state) {
    final itemId = widget.source.itemId;
    if (itemId == null) return state;

    final memo = _displayMemo;
    if (memo != null && identical(state, memo.raw)) return memo.display;

    final seen = <Object>{};
    final displayState = state.filterItems((item) => seen.add(itemId(item)));
    _displayMemo = (raw: state, display: displayState);

    return displayState;
  }

  void _onQueryCommitted(String committedQuery) {
    final wasSearching = _searchModeNotifier.value;
    final isSearchMode = _isSearchQuery(committedQuery);
    final search = widget.source.search;
    final action = switch (search) {
      final AsyncSearch<T> s => s.cachePolicy.actionFor(
        wasSearching: wasSearching,
        isSearching: isSearchMode,
      ),
      NoSearch() => CacheAction.refresh,
    };

    _searchModeNotifier.value = isSearchMode;
    _applyCacheAction(action);

    final observer = widget.observer;
    observer?.onQueryCommitted(committedQuery);
    if (wasSearching != isSearchMode) observer?.onSearchModeChanged(isSearchMode: isSearchMode);
  }

  void _applyCacheAction(CacheAction action) {
    switch ((action, _normalSnapshot)) {
      case (.restoreNormal, final snapshot?):
        _controller.value = snapshot.state;
        _lastPageSignal = snapshot.signal;
        _normalSnapshot = null;
      case (.snapshotThenRefresh, _):
        _normalSnapshot = (state: _controller.value, signal: _lastPageSignal);
        _resetPaging();
      case (.refresh, _) || (.restoreNormal, null):
        _resetPaging();
    }
  }

  /// Refreshes the controller and clears the end signal, so a signal-based policy starts the reloaded
  /// stream fresh instead of reading the previous stream's last signal.
  void _resetPaging() {
    _lastPageSignal = null;
    _controller.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = widget.surfaces;

    final list = PagingListener(
      controller: _controller,
      builder: (_, state, fetchNextPage) => ValueListenableBuilder(
        valueListenable: _searchModeNotifier,
        builder: (_, isSearchMode, _) => PagedView(
          state: _dedupedForDisplay(state),
          fetchNextPage: fetchNextPage,
          itemBuilder: widget.itemBuilder,
          grouping: widget.grouping,
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

    return switch (widget.source.refresh) {
      NoRefresh() => list,
      PullToRefresh(:final refreshBuilder) => RefreshBinding(
        onRefresh: _onRefresh,
        refreshBuilder: refreshBuilder,
        child: list,
      ),
    };
  }

  Future<void> _onRefresh() {
    widget.observer?.onRefresh();

    return Future.sync(_resetPaging);
  }
}
