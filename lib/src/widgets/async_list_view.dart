/// @docImport '/src/data/pagination/models/empty_page_behaviour.dart';
/// @docImport '/src/data/search/models/search_cache_policy.dart';
/// @docImport 'list_smith.dart';
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '/src/data/control/models/list_smith_controller.dart';
import '/src/data/control/models/list_smith_controller_host.dart';
import '/src/data/grouping/models/grouping.dart';
import '/src/data/observer/models/list_smith_observer.dart';
import '/src/data/pagination/enums/fetch_trigger.dart';
import '/src/data/pagination/models/empty_page_context.dart';
import '/src/data/pagination/models/end_context.dart';
import '/src/data/pagination/models/page_request.dart';
import '/src/data/pagination/utils/fetch_trigger_resolver.dart';
import '/src/data/presentation/models/async_list_surfaces.dart';
import '/src/data/presentation/models/list_scroll_config.dart';
import '/src/data/presentation/typedefs/item_builder.dart';
import '/src/data/presentation/typedefs/no_results_builder.dart';
import '/src/data/refresh/models/refresh.dart';
import '/src/data/refresh/models/reload.dart';
import '/src/data/refresh/models/reload_context.dart';
import '/src/data/search/enums/cache_action.dart';
import '/src/data/search/extensions/search_cache_policy_resolver_extension.dart';
import '/src/data/search/models/search.dart';
import '/src/data/search/models/search_page_request.dart';
import '/src/data/source/list_source.dart';
import '/src/utils/query_debouncer.dart';
import 'defaults/neutral_loading_indicator.dart';
import 'paged_view.dart';
import 'refresh_binding.dart';

/// The async engine behind [ListSmith.async]: owns the paging controller, wires pull-to-refresh, and
/// runs feed and search as two views on that one controller.
///
/// Unexported, built by [ListSmith] for an [AsyncSource]. The fetch closure reads the debounced
/// committed query: empty runs [AsyncSource.fetchPage], non-empty runs the [AsyncSearch] fetcher, and
/// a change of committed query runs that search's cache policy against the controller. Every default
/// is already resolved by [ListSmith.async].
class AsyncListView<T extends Object> extends StatefulWidget {
  /// The async, paginated source: its fetchers, end policy, and search cache policy.
  final AsyncSource<T> source;

  /// Builds the widget for each item.
  final ItemBuilder<T> itemBuilder;

  /// Splits the visible items into sections. [NoGrouping] (the default) renders a flat list.
  final Grouping<T> grouping;

  /// Builds the separator between items. Null for none.
  final IndexedWidgetBuilder? separatorBuilder;

  /// The current search query. Empty runs the feed, non-empty runs search.
  final String query;

  /// Minimum trimmed query length before a search runs. Below it the query counts as empty.
  final int minSearchLength;

  /// How long to wait after [query] changes before it takes effect. [Duration.zero] is immediate.
  final Duration searchDebounce;

  /// Builds the surface shown when the source yields no items. Null uses the neutral default.
  final WidgetBuilder? emptyBuilder;

  /// Builds the surface shown when a search matches nothing. Null uses the neutral default.
  final NoResultsBuilder? noResultsBuilder;

  /// The async-only override surfaces (page loading and error, end-of-list footer, refresh indicator).
  final AsyncListSurfaces surfaces;

  /// Scroll and layout configuration for the underlying scrollable.
  final ListScrollConfig scroll;

  /// Lifecycle observer for logging or telemetry. Null is silent.
  final ListSmithObserver? observer;

  /// Handle the consumer refreshes this list through. Null leaves refresh gesture-only.
  final ListSmithController? controller;

  /// Creates the async paged list around an [AsyncSource].
  const new({
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
    this.controller,
    super.key,
  });

  @override
  State<AsyncListView<T>> createState() => _AsyncListViewState<T>();
}

class _AsyncListViewState<T extends Object> extends State<AsyncListView<T>>
    implements ListSmithControllerHost {
  late final _debouncer = QueryDebouncer(onCommitted: _onQueryCommitted);
  late final _pager = PagingController<int, T>(getNextPageKey: _nextPageKey, fetchPage: _fetchPage);

  /// The normal-mode paging state (with its end signal) kept aside while searching, for
  /// [KeepCachePolicy].
  ({PagingState<int, T> state, Object? signal})? _normalSnapshot;

  /// The current stream's most recent end signal, fed to the end policy via
  /// [EndContext.lastPageSignal]. Not derivable from the paging state, so it lives here: it resets
  /// on refresh and snapshots with [_normalSnapshot] across a search toggle.
  Object? _lastPageSignal;

  /// Bumped by everything that makes in-flight work stale: a reset, a query change, a commit,
  /// dispose. ISP's token covers its own fetch, the post-await writes here compare against this.
  var _generation = 0;

  /// The trigger the next paging-controller fetch reports, latched by a reset because the re-fetch it
  /// causes arrives later, from the view. One-shot, so the page after it is derived again.
  FetchTrigger? _pendingTrigger;

  /// The page whose last attempt threw, so its re-fetch reports [FetchTrigger.retry]. Not derivable
  /// from paging state: ISP clears `error` before re-invoking the fetch.
  int? _lastFailedPageIndex;

  /// Memo for [_dedupedForDisplay], keyed on paging-state identity: the controller hands out the
  /// same [PagingState] until the data changes, so a rebuild that leaves it alone reuses the view
  /// instead of re-running the O(loaded) pass. One cell, so the pair can't drift.
  ({PagingState<int, T> raw, PagingState<int, T> display})? _displayMemo;

  /// Whether the controller currently reflects search results (drives the empty/no-results surface).
  late final ValueNotifier<bool> _searchModeNotifier;

  /// The reload running now. A second trigger joins it rather than starting a rival, unless the
  /// list moved on under it. Null when none is in flight.
  _ReloadRun<T>? _running;

  @override
  void initState() {
    super.initState();

    _debouncer.seed(widget.query);
    _searchModeNotifier = ValueNotifier(_isSearchQuery(_debouncer.committedQuery));
    _pager.addListener(_maybeAdvancePastEmptyPage);
    widget.controller?.attach(this);
  }

  @override
  void didUpdateWidget(AsyncListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.detach();
      widget.controller?.attach(this);
    }
    if (widget.query != oldWidget.query) _debouncer.schedule(widget.query, widget.searchDebounce);
  }

  @override
  void dispose() {
    _generation++; // a reload outliving the list must not write into it
    widget.controller?.detach();
    _debouncer.dispose();
    _pager.dispose();
    _searchModeNotifier.dispose();

    super.dispose();
  }

  bool _isSearchQuery(String query) => query.isNotEmpty && widget.source.supportsSearch;

  /// The paging controller's fetch: consumes any latched trigger, then threads the signal forward.
  Future<List<T>> _fetchPage(int pageKey) async {
    final generation = _generation;
    final trigger = resolveTrigger(
      pageIndex: pageKey,
      pending: _pendingTrigger,
      lastFailedPageIndex: _lastFailedPageIndex,
    );
    _pendingTrigger = null;

    final (items, signal) = await _fetchPageRaw(pageKey, _lastPageSignal, trigger);
    if (generation == _generation) _lastPageSignal = signal;

    return items;
  }

  /// Fetches one page in the current mode, leaving [_lastPageSignal] to the caller: [_fetchPage]
  /// threads it forward, a reload threads its own and commits via [_commit].
  ///
  /// A superseded page stays silent and leaves the retry marker alone, since the list drops it. An
  /// error still fires `onError`: the request did fail, whoever was waiting.
  Future<(List<T>, Object?)> _fetchPageRaw(
    int pageKey,
    Object? previousSignal,
    FetchTrigger trigger,
  ) async {
    final generation = _generation;
    final source = widget.source;
    final search = source.search;
    final committedQuery = _debouncer.committedQuery;
    final isSearchMode = _isSearchQuery(committedQuery);

    try {
      final (items, signal) = switch (search) {
        final AsyncSearch<T> s when isSearchMode => await s.fetchPage(
          SearchPageRequest(
            query: committedQuery,
            pageIndex: pageKey,
            pageSize: source.pageSize,
            trigger: trigger,
            previousSignal: previousSignal,
          ),
        ),
        AsyncSearch<T>() || NoSearch() => await source.fetchPage(
          PageRequest(
            pageIndex: pageKey,
            pageSize: source.pageSize,
            trigger: trigger,
            previousSignal: previousSignal,
          ),
        ),
      };
      final pageItems = items.toList(growable: false);
      if (generation == _generation) {
        _lastFailedPageIndex = null;
        widget.observer?.onPageLoaded(pageKey, pageItems.length, isSearchMode: isSearchMode);
      }

      return (pageItems, signal);
    } on Object catch (error, stackTrace) {
      if (generation == _generation) _lastFailedPageIndex = pageKey;
      widget.observer?.onError(error, stackTrace);

      rethrow;
    }
  }

  /// The next 0-based page key for [state], or `null` once [AsyncSource.endPolicy] reports the end.
  /// Keys are the page count so far, so they stay sequential.
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

  /// A display-only copy of [state] dropping any item whose [AsyncSource.itemId] key already
  /// appeared, so overlapping pages don't render a row twice. Null `itemId` returns [state] as-is.
  ///
  /// The controller's own pages stay raw, so [_nextPageKey] feeds the end policy what the backend
  /// actually returned and a fully-duplicate page is not read as end-of-data. `filterItems` walks
  /// the pages flattened, so `seen` threads across them. O(loaded) per state change, memoised on
  /// state identity in [_displayMemo]. Rationale in APPENDIX.md, `overlap-dedup`.
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

  /// Pages the controller past an empty page when [EmptyPageBehaviour.shouldAdvance] says so, since
  /// the pager parks there with nothing on screen to scroll.
  ///
  /// Runs on every controller change, deferred to a microtask so it never re-enters the controller's
  /// own notification, and re-checked on arrival because the state can move in between.
  void _maybeAdvancePastEmptyPage() {
    if (!_shouldAdvancePastEmpty(_pager.value)) return;

    scheduleMicrotask(() {
      if (mounted && _shouldAdvancePastEmpty(_pager.value)) _pager.fetchNextPage();
    });
  }

  /// Gathers the [EmptyPageContext] and lets [EmptyPageBehaviour.shouldAdvance] decide. Emptiness
  /// comes off the de-duplicated view (what the user sees), more-available off the raw pages. Gates
  /// both the auto-fetch and the loading surface meanwhile, so the two can't disagree.
  bool _shouldAdvancePastEmpty(PagingState<int, T> state) =>
      widget.source.onEmptyPage.shouldAdvance(
        EmptyPageContext(
          isEmpty: _dedupedForDisplay(state).items?.isEmpty ?? false,
          moreAvailable: _nextPageKey(state) != null,
          pagesLoaded: state.pages?.length ?? 0,
        ),
      );

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
        // No fetch here, so no trigger to latch: the next one is whatever the user does next.
        _generation++;
        _lastFailedPageIndex = null;
        _replacePagingState(snapshot.state);
        _lastPageSignal = snapshot.signal;
        _normalSnapshot = null;
      case (.snapshotThenRefresh, _):
        // A snapshot means settled state. The re-fetch after a restore overwrites both flags
        // anyway, so this is about intent, not behaviour.
        _normalSnapshot = (
          state: _pager.value.copyWith(isLoading: false, error: null),
          signal: _lastPageSignal,
        );
        _resetPaging(.queryChanged);
      case (.refresh, _) || (.restoreNormal, null):
        _resetPaging(.queryChanged);
    }
  }

  /// Swaps the whole paging state and drops any fetch still in flight. A bare `value =` wouldn't
  /// move the pager's token, so a landed fetch would still apply. Every direct write comes through
  /// here.
  void _replacePagingState(PagingState<int, T> next) {
    _pager.cancel();
    _pager.value = next;
  }

  /// Restarts the stream: invalidates in-flight writes, latches [nextTrigger] for the re-fetch this
  /// drives, and clears the end signal so a signal policy can't read the old stream's last one.
  void _resetPaging(FetchTrigger nextTrigger) {
    _generation++;
    _lastFailedPageIndex = null;
    _pendingTrigger = nextTrigger;
    _lastPageSignal = null;
    _pager.refresh();
  }

  // --- The engine side of a reload, reached through a [_ReloadRun]. ---

  /// Whether the current stream's fetcher threads a per-page signal, which forces a sequential,
  /// atomic reload.
  bool get _isSignalBased => switch (widget.source.search) {
    final AsyncSearch<T> s when _isSearchQuery(_debouncer.committedQuery) =>
      s.fetchPage.reportsSignal,
    AsyncSearch<T>() || NoSearch() => widget.source.fetchPage.reportsSignal,
  };

  /// Replaces the loaded pages with [pages] atomically, recording [lastSignal] as the new end signal.
  void _commit(List<List<T>> pages, {Object? lastSignal}) {
    _generation++;
    _lastPageSignal = lastSignal;
    final keys = [for (var index = 0; index < pages.length; index++) index];
    final probe = PagingState<int, T>(pages: pages, keys: keys);

    _replacePagingState(
      PagingState<int, T>(pages: pages, keys: keys, hasNextPage: _nextPageKey(probe) != null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = widget.surfaces;

    final list = PagingListener(
      controller: _pager,
      builder: (_, state, fetchNextPage) => ValueListenableBuilder(
        valueListenable: _searchModeNotifier,
        builder: (context, isSearchMode, _) {
          // AdvanceToFirstNonEmpty pages past an empty page itself, so show the loading surface while
          // it does, so the empty surface is reserved for the true end (or the maxPages give-up).
          if (_shouldAdvancePastEmpty(state)) {
            return surfaces.firstPageLoadingBuilder?.call(context) ??
                const NeutralLoadingIndicator();
          }

          return PagedView(
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
          );
        },
      ),
    );

    return switch (widget.source.refresh) {
      NoRefresh() => list,
      PullToRefresh(:final refreshBuilder) => RefreshBinding(
        onRefresh: refresh,
        refreshBuilder: refreshBuilder,
        child: list,
      ),
    };
  }

  /// The one refresh entry point, gesture or controller. Joins the reload already running, unless
  /// the list moved on under it, in which case a fresh one starts.
  @override
  Future<void> refresh() {
    final running = _running;
    if (running != null && !running.isStale) return running.done;

    final run = _ReloadRun(this, .refresh);
    _running = run;
    widget.observer?.onRefresh();
    unawaited(
      _configuredReload.run(run).whenComplete(() {
        if (identical(_running, run)) _running = null;
        run.finish();
      }),
    );

    return run.done;
  }

  /// The pull's [Reload]. A `NoRefresh` list has no gesture but is still refreshable from code, so
  /// it falls back to the pager's own reset.
  Reload get _configuredReload => switch (widget.source.refresh) {
    PullToRefresh(:final reload) => reload,
    NoRefresh() => const ResetToFirstPage(),
  };
}

/// One reload's handle onto the engine, the [ReloadContext] a [Reload] runs through.
///
/// One per run rather than the State itself, so a reload knows its own facts: the trigger its pages
/// report, and whether the list moved on since it began.
final class _ReloadRun<T extends Object> implements ReloadContext<T> {
  final _AsyncListViewState<T> _engine;

  /// What every page fetched through this run reports.
  final FetchTrigger trigger;

  final _done = Completer<void>();

  /// The generation this run belongs to. Its own writes move it along, so only another writer can
  /// make it stale.
  int _epoch;

  new(this._engine, this.trigger) : _epoch = _engine._generation;

  /// Completes once the reload finishes, committed or not, after the engine has let go of the run.
  Future<void> get done => _done.future;

  @override
  bool get isStale => _engine._generation != _epoch;

  @override
  List<List<T>> get loadedPages => _engine._pager.value.pages ?? [];

  @override
  bool get isSignalBased => _engine._isSignalBased;

  @override
  Future<(List<T>, Object?)> fetch(int index, Object? previousSignal) =>
      _engine._fetchPageRaw(index, previousSignal, trigger);

  @override
  void commit(List<List<T>> pages, {Object? lastSignal}) {
    if (isStale) return;
    _engine._commit(pages, lastSignal: lastSignal);
    _epoch = _engine._generation;
  }

  @override
  void reset() {
    _engine._resetPaging(trigger);
    _epoch = _engine._generation;
  }

  /// Marks the run finished. The engine calls it once it has let go of the run.
  void finish() => _done.complete();
}
