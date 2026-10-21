/// @docImport 'list_smith.dart';
library;

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:multi_value_listenable_builder_typed/multi_value_listenable_builder_typed.dart';

import '/src/data/control/control.dart';
import '/src/data/edits/edits.dart';
import '/src/data/grouping/grouping.dart';
import '/src/data/observer/observer.dart';
import '/src/data/pagination/pagination.dart';
import '/src/data/presentation/presentation.dart';
import '/src/data/refresh/refresh.dart';
import '/src/data/search/search.dart';
import '/src/data/source/source.dart';
import '/src/utils/query_debouncer.dart';
import 'paged_view.dart';
import 'refresh_binding.dart';
import 'row_transitions_notifier.dart';

/// The async engine behind [ListSmith.async]: owns the paging state and every fetch into it, wires
/// pull-to-refresh, and runs feed and search as 2 views on that one state.
@internal
class const AsyncListView<T extends Object>({
  /// The fetchers, end policy and search cache policy.
  required final AsyncSource<T> source,

  /// Builds the widget for each item.
  required final ItemBuilder<T> itemBuilder,

  /// Splits the visible items into sections. [NoGrouping] (the default) renders a flat list.
  required final Grouping<T> grouping,

  /// The current search query. Empty runs the feed, non-empty runs search.
  required final String query,

  /// Minimum trimmed query length before a search runs. Below it the query counts as empty.
  required final int minSearchLength,

  /// How long to wait after [query] changes before it takes effect. [Duration.zero] is immediate.
  required final Duration searchDebounce,

  /// The async-only override surfaces: page loading and error, end-of-list footer.
  required final AsyncListSurfaces surfaces,

  /// Scroll and layout configuration for the underlying scrollable.
  required final ListScrollConfig scrollConfig,

  /// Builds the separator between items. Null for none.
  final IndexedWidgetBuilder? separatorBuilder,

  /// Builds the surface shown when the source yields no items. Null uses the neutral default.
  final WidgetBuilder? emptyBuilder,

  /// Builds the surface shown when a search matches nothing. Null uses the neutral default.
  final NoResultsBuilder? noResultsBuilder,

  /// Lifecycle events for logging or telemetry. Null is silent.
  final ListSmithObserver? observer,

  /// Refreshes this list from code. Null leaves refresh gesture-only.
  final ListSmithController<T>? controller,
  super.key,
}) extends StatefulWidget {
  /// Creates it.
  this;

  @override
  State<AsyncListView<T>> createState() => _AsyncListViewState<T>();
}

class _AsyncListViewState<T extends Object>()
    extends State<AsyncListView<T>>
    with TickerProviderStateMixin
    implements ListSmithControllerHost<T> {
  late final _debouncer = QueryDebouncer(onCommitted: _onQueryCommitted);

  /// The pages and where the stream stands. Only the engine writes it, so a fetch starts only when the
  /// engine asks for one.
  final _pagingStateNotifier = ValueNotifier(PagingState<T>());

  /// The normal-mode stream kept aside while searching, for [KeepCachePolicy].
  _NormalSnapshot<T>? _normalSnapshot;

  /// The current stream's last end signal, fed to the end policy. Not derivable from the paging state,
  /// so it lives here: resets on refresh, and rides [_normalSnapshot] across a search toggle.
  Object? _lastPageSignal;

  /// Bumped by everything that makes in-flight work stale: a reset, a query change, a commit, dispose.
  /// Every write after an await compares against it.
  var _generation = 0;

  /// The page whose last attempt threw, so its re-fetch reports [FetchTrigger.retry]. Outlives the
  /// exception on the paging state: a depth reload's commit clears that, and the page is still a retry.
  int? _lastFailedPageIndex;

  /// Whether a row near the end already booked the next page this frame.
  var _isNextPageBooked = false;

  /// Memo for [_displayFor], keyed on paging-state identity, the edit counter and the mode, so a rebuild
  /// that changes none of them skips the O(loaded) pass. One cell, so the parts can't drift.
  ({PagingState<T> raw, int editStamp, bool isSearchMode, _Display<T> display})? _displayMemo;

  final _editStoreNotifier = EditStoreNotifier<T>();

  /// Whether the controller currently reflects search results (drives the empty/no-results surface).
  late final ValueNotifier<bool> _searchModeNotifier;

  /// The run in flight, a reload or a 1st-page load, null when there is none.
  _ReloadRun<T>? _runningReload;

  /// The rows edits are animating. Idle unless the source has an [EditTransition].
  late final _rowTransitionsNotifier = RowTransitionsNotifier<T>(vsync: this);

  /// How far a pull pushes the list now. The refresh binding writes it, the rows hold still against it.
  final _pullExtentNotifier = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();

    _debouncer.seed(widget.query);
    _searchModeNotifier = ValueNotifier(_isSearchQuery(_debouncer.committedQuery));
    _pagingStateNotifier
      ..addListener(_dropDeadEdits)
      ..addListener(_maybeAdvancePastEmptyPage);
    _editStoreNotifier.addListener(_maybeAdvancePastEmptyPage);
    widget.controller?.attach(this);
    // A run too, so a reload asked meanwhile meets this load instead of cutting it.
    _startRun(.initialLoad, (run) => run.reset());
  }

  @override
  void didUpdateWidget(AsyncListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.detach();
      widget.controller?.attach(this);
    }
    if (widget.query != oldWidget.query) _debouncer.schedule(widget.query, widget.searchDebounce);
    // Turned off mid-animation: a leaving row would otherwise build its deleted item again.
    if (widget.source.editTransition is NoEditTransition) _rowTransitionsNotifier.settle();
  }

  @override
  void dispose() {
    _generation++; // a reload outliving the list must not write into it
    widget.controller?.detach();
    _debouncer.dispose();
    _pagingStateNotifier.dispose();
    _searchModeNotifier.dispose();
    _editStoreNotifier.dispose();
    _rowTransitionsNotifier.dispose();
    _pullExtentNotifier.dispose();

    super.dispose();
  }

  bool _isSearchQuery(String query) => query.isNotEmpty && widget.source.supportsSearch;

  /// What the current mode's fetcher returns beside its items.
  SignalKind get _signalKind => switch (widget.source.search) {
    final AsyncSearch<T> asyncSearch when _isSearchQuery(_debouncer.committedQuery) =>
      asyncSearch.fetchPage.signalKind,
    AsyncSearch<T>() || NoSearch() => widget.source.fetchPage.signalKind,
  };

  /// Fetches the next page into the current stream, unless one is already on its way or the stream has
  /// ended. [trigger] is what a restart's 1st page reports, otherwise each page derives its own.
  Future<void> _fetchNextPage({FetchTrigger? trigger}) async {
    final state = _pagingStateNotifier.value;
    if (!mounted || state.isLoading || !state.hasNextPage) return;

    final generation = _generation;
    final loadingState = state.loading();
    _pagingStateNotifier.value = loadingState;
    final pageIndex = _nextPageIndex(loadingState.pages);
    if (pageIndex == null) {
      _pagingStateNotifier.value = loadingState.copyWith(hasNextPage: false, isLoading: false);

      return;
    }
    final pages = loadingState.pages ?? const [];
    final readStamp = _editStoreNotifier.value; // before the await, so a later edit is newer
    final previousSignal = _signalKind.threadsSignal ? _lastPageSignal : null;

    try {
      final pageRead = await _readWithRereads(
        pages,
        pageIndex,
        readStamp: readStamp,
        previousSignal: previousSignal,
        trigger: trigger,
      );
      if (pageRead == null) return;

      final (:items, :signal) = pageRead;
      _lastPageSignal = signal;
      final latestState = _pagingStateNotifier.value;
      _pagingStateNotifier.value = latestState.copyWith(
        pages: [
          ...?latestState.pages,
          LoadedPage(items: items, readStamp: readStamp, previousSignal: previousSignal),
        ],
        isLoading: false,
      );
    } on Exception catch (exception) {
      // Only Exceptions: an Error is a bug in the fetcher, so it goes on to the app and the list waits.
      if (generation == _generation) {
        _pagingStateNotifier.value = _pagingStateNotifier.value.failed(exception);
      }
    }
  }

  /// Reads page [pageIndex], plus the rows that removals since [pages] were read shifted into the pages
  /// before it. Null once the list moved on.
  Future<({List<T> items, Object? signal})?> _readWithRereads(
    List<LoadedPage<T>> pages,
    int pageIndex, {
    required int readStamp,
    required Object? previousSignal,
    required FetchTrigger? trigger,
  }) async {
    final generation = _generation;
    final loadedItems = pages.expand((page) => page.items);
    final lastReadStamp = pages.lastOrNull?.readStamp ?? readStamp;
    int rereadCountFor(RemovalStamps removalStamps) => rereadPageCount(
      removalStamps.after(lastReadStamp).length,
      pageSize: widget.source.pageSize,
      maxCount: pages.length,
    );
    final removalStamps = _removalStampsSince(lastReadStamp, loadedItems);
    // A removal still out can reach the server between 2 reads sent together, so the page goes 1st.
    final isRemovalOut = removalStamps.after(readStamp).isNotEmpty;
    final rereadCount = isRemovalOut ? 0 : rereadCountFor(removalStamps);

    final pageFuture = _fetchPageRaw(
      pageIndex,
      previousSignal,
      resolveTrigger(
        pageIndex: pageIndex,
        pending: trigger,
        lastFailedPageIndex: _lastFailedPageIndex,
      ),
    );
    // Future.wait, not .wait, so a failed read reaches the error surface as itself.
    final pageReads = await Future.wait(
      _rereadsBefore(pages, rereadCount).followedBy([pageFuture]),
      eagerError: true,
    );
    if (generation != _generation) return null;

    final landedRemovalStamps = _removalStampsSince(lastReadStamp, loadedItems);
    // Then the pages before, if a removal was out or came in while the page was.
    final lateRereadCount = isRemovalOut || landedRemovalStamps.after(readStamp).isNotEmpty
        ? rereadCountFor(landedRemovalStamps)
        : 0;
    final rereads = lateRereadCount == 0
        ? pageReads.take(rereadCount)
        : await Future.wait(_rereadsBefore(pages, lateRereadCount), eagerError: true);
    if (generation != _generation) return null;

    final (items, signal) = pageReads.last;
    final itemIdGetter = widget.source.itemIdGetter;
    late final knownIds = loadedItems.followedBy(items).map(itemIdGetter).toSet();

    return (
      // Only the rows the list lacks, so the end policy still counts what this page sent.
      items: rereads
          .expand((read) => read.$1)
          .whereNot((item) => knownIds.contains(itemIdGetter(item)))
          .followedBy(items)
          .toList(growable: false),
      signal: signal,
    );
  }

  /// Books the next page for after this frame, since a row's build is what asks. Once per frame.
  void _onNearEnd() {
    if (_isNextPageBooked) return;

    _isNextPageBooked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isNextPageBooked = false;
      unawaited(_fetchNextPage());
    });
  }

  /// Asks again for the page that failed, from an error surface.
  void _retryPage() {
    if (_pagingStateNotifier.value.pages == null) {
      _startRun(.retry, (run) => run.reset()); // a run, like every 1st-page load
    } else {
      unawaited(_fetchNextPage());
    }
  }

  /// Fetches one page in the current mode, leaving [_lastPageSignal] to the caller: [_fetchNextPage]
  /// threads it forward, a reload threads its own and commits via [_commit].
  ///
  /// A superseded page stays silent and leaves the retry marker alone, since the list drops it. An
  /// exception still fires `onError`: the request did fail, whoever was waiting.
  Future<(List<T>, Object?)> _fetchPageRaw(
    int pageIndex,
    Object? previousSignal,
    FetchTrigger trigger,
  ) async {
    final generation = _generation;
    final isSearchMode = _isSearchQuery(_debouncer.committedQuery);

    try {
      final (items, signal) = await _requestPage(pageIndex, previousSignal, trigger);
      final pageItems = items.toList(growable: false);
      if (kDebugMode) {
        _reportIfOutOfOrder(pageIndex, pageItems, _comparatorFor(isSearchMode: isSearchMode));
      }
      if (generation == _generation) {
        // Only its own, since a read beside it may have just failed.
        if (_lastFailedPageIndex == pageIndex) _lastFailedPageIndex = null;
        widget.observer?.onPageLoaded(pageIndex, pageItems.length, isSearchMode: isSearchMode);
      }

      return (pageItems, signal);
    } on Exception catch (exception, stackTrace) {
      if (generation == _generation) _lastFailedPageIndex = pageIndex;
      widget.observer?.onError(exception, stackTrace);

      rethrow;
    }
  }

  /// Asks the current mode's fetcher for page [pageIndex].
  Future<(Iterable<T>, Object?)> _requestPage(
    int pageIndex,
    Object? previousSignal,
    FetchTrigger trigger,
  ) {
    final source = widget.source;
    final committedQuery = _debouncer.committedQuery;

    return switch (source.search) {
      final AsyncSearch<T> asyncSearch when _isSearchQuery(committedQuery) => asyncSearch.fetchPage(
        SearchPageRequest(
          query: committedQuery,
          pageIndex: pageIndex,
          pageSize: source.pageSize,
          trigger: trigger,
          previousSignal: previousSignal,
        ),
      ),
      AsyncSearch<T>() || NoSearch() => source.fetchPage(
        PageRequest(
          pageIndex: pageIndex,
          pageSize: source.pageSize,
          trigger: trigger,
          previousSignal: previousSignal,
        ),
      ),
    };
  }

  /// Reports a page not strictly in [comparator]'s order, rather than throwing, so it still lands.
  void _reportIfOutOfOrder(int pageIndex, List<T> pageItems, Comparator<T>? comparator) {
    // A tie is out of order too.
    if (comparator == null || pageItems.isSorted((a, b) => comparator(a, b) < 0 ? -1 : 1)) return;

    FlutterError.reportError(
      FlutterErrorDetails(
        exception: FlutterError(
          "Page $pageIndex isn't in the list's order. Match the server's, ties included.",
        ),
        library: 'list_smith',
      ),
    );
  }

  /// The order rows keep. Search results come in the server's own order, so they have none.
  Comparator<T>? _comparatorFor({required bool isSearchMode}) =>
      isSearchMode ? null : widget.source.order.comparator;

  /// The rows that left their place after [readStamp]: removed, going out, or sorted elsewhere by an
  /// edit. [loadedItems] and new items count.
  RemovalStamps _removalStampsSince(int readStamp, Iterable<T> loadedItems) {
    final comparator = _comparatorFor(isSearchMode: _isSearchQuery(_debouncer.committedQuery));
    // The 1st copy, since a row read either side of its move down sits in 2 pages.
    late final loadedItemsById = loadedItems.groupFoldBy<Object, T>(
      widget.source.itemIdGetter,
      (firstItem, item) => firstItem ?? item,
    );

    return _editStoreNotifier.removalStampsSince(
      readStamp,
      goingOutIds: _rowTransitionsNotifier.leavingIds,
      leavesPlacePredicate: (itemId, replacedItem, editedItem) {
        final listedItem = loadedItemsById[itemId] ?? replacedItem;
        if (listedItem == null) return false;

        return editedItem == null ||
            (comparator != null && comparator(listedItem, editedItem) != 0);
      },
    );
  }

  Iterable<Future<(List<T>, Object?)>> _rereadsBefore(List<LoadedPage<T>> pages, int count) =>
      Iterable.generate(count, (offset) => pages.length - count + offset).map(
        (rereadPageIndex) => _fetchPageRaw(
          rereadPageIndex,
          pages[rereadPageIndex].previousSignal,
          resolveTrigger(
            pageIndex: rereadPageIndex,
            pending: null,
            lastFailedPageIndex: _lastFailedPageIndex,
            isReread: true,
          ),
        ),
      );

  /// The index of the page after [pages], which is their count, or null once [AsyncSource.endPolicy]
  /// reports the end.
  int? _nextPageIndex(List<LoadedPage<T>>? pages) {
    if (pages == null || pages.isEmpty) return 0;

    final endContext = EndContext(
      // A view, not a copy, so the check stays O(1). Pages lists never change once built.
      pageItemCounts: UnmodifiableListView(pages.map((page) => page.items.length)),
      pageSize: widget.source.pageSize,
      lastPageSignal: _lastPageSignal,
    );

    return widget.source.endPolicy.hasReachedEnd(endContext) ||
            _signalKind.endsList(_lastPageSignal)
        ? null
        : pages.length;
  }

  /// What renders, [state] with the local edits applied and overlap duplicates dropped, and the ids
  /// in it. The paging state's own pages stay raw, why in APPENDIX.md, `overlap-dedup`.
  _Display<T> _displayFor(PagingState<T> state) {
    final pages = state.pages;
    if (pages == null) return (state: state, shownIds: const {});

    final editStamp = _editStoreNotifier.value;
    final isSearchMode = _searchModeNotifier.value;
    final displayMemo = _displayMemo;
    if (displayMemo != null &&
        identical(state, displayMemo.raw) &&
        displayMemo.editStamp == editStamp &&
        displayMemo.isSearchMode == isSearchMode) {
      return displayMemo.display;
    }

    final display = _editStoreNotifier.isEmpty
        ? _dedupedDisplay(state)
        : _editedDisplay(state, pages, isSearchMode: isSearchMode);
    _displayMemo = (raw: state, editStamp: editStamp, isSearchMode: isSearchMode, display: display);

    return display;
  }

  /// No edits keeps the plain de-dup pass, the one benchmark/micro/dedup_scaling.dart measures.
  _Display<T> _dedupedDisplay(PagingState<T> state) {
    final itemIdGetter = widget.source.itemIdGetter;
    final seenIds = <Object>{};

    return (state: state.filterItems((item) => seenIds.add(itemIdGetter(item))), shownIds: seenIds);
  }

  _Display<T> _editedDisplay(
    PagingState<T> state,
    List<LoadedPage<T>> pages, {
    required bool isSearchMode,
  }) {
    final comparator = _comparatorFor(isSearchMode: isSearchMode);
    final (pages: displayPages, :shownIds) = _editStoreNotifier.applyTo(
      pages,
      itemIdGetter: widget.source.itemIdGetter,
      groupOf: widget.grouping.groupOf,
      acceptsNewItems: !isSearchMode, // only the server knows what matches the query
      sortedPlacement: comparator == null
          ? null
          : (
              comparator: comparator,
              mayHaveRowsAfter: state.hasNextPage || !widget.source.endPolicy.stopsAtDataEnd,
            ),
    );

    return (state: state.copyWith(pages: displayPages), shownIds: shownIds);
  }

  /// Parked pages count too, so a feed kept while searching comes back with its edits.
  void _dropDeadEdits() {
    if (_editStoreNotifier.isEmpty) return;

    _editStoreNotifier.dropCaughtUp(
      // Mapped first: a `const []` is a list of `Never`, so `followedBy` would reject the parked pages.
      (_pagingStateNotifier.value.pages ?? const [])
          .map((page) => page.readStamp)
          .followedBy((_normalSnapshot?.state.pages ?? const []).map((page) => page.readStamp)),
    );
  }

  /// Pages past an empty page when [EmptyPageBehaviour.shouldAdvance] says so, since with no rows on
  /// screen no row near the end ever asks for the next one.
  void _maybeAdvancePastEmptyPage() {
    if (!_shouldAdvancePastEmpty(_pagingStateNotifier.value)) return;

    // Deferred so it never re-enters the state's own notification, re-checked since the state can move
    // in between.
    scheduleMicrotask(() {
      if (mounted && _shouldAdvancePastEmpty(_pagingStateNotifier.value)) {
        unawaited(_fetchNextPage());
      }
    });
  }

  /// Whether to page past an empty screen. Emptiness comes off what the user sees, more-available off
  /// the raw pages. Gates both the auto-fetch and the loading surface, so the two can't disagree.
  bool _shouldAdvancePastEmpty(PagingState<T> state) {
    // No page yet isn't an empty list.
    final isEmpty = state.pages != null && _displayFor(state).shownIds.isEmpty;
    final isMoreAvailable = _nextPageIndex(state.pages) != null;
    // The user emptied it, not the server, so there's more to show.
    if (isEmpty && state.items.isNotEmpty && isMoreAvailable) return true;

    return widget.source.onEmptyPage.shouldAdvance(
      EmptyPageContext(
        isEmpty: isEmpty,
        isMoreAvailable: isMoreAvailable,
        pagesLoaded: state.pages?.length ?? 0,
      ),
    );
  }

  void _onQueryCommitted(String committedQuery) {
    final wasSearching = _searchModeNotifier.value;
    final isSearchMode = _isSearchQuery(committedQuery);
    final cacheAction = widget.source.search.cacheActionFor(
      wasSearching: wasSearching,
      isSearching: isSearchMode,
    );

    _searchModeNotifier.value = isSearchMode;
    final keptSnapshot = _runCacheAction(cacheAction);

    final observer = widget.observer;
    observer?.onQueryCommitted(committedQuery);
    if (wasSearching != isSearchMode) observer?.onSearchModeChanged(isSearchMode: isSearchMode);
    if (keptSnapshot == null) {
      observer?.onReload(.queryChanged); // reset, not restored

      return;
    }
    // Paid after the query facts, so the observer's events stay in order.
    final debt = keptSnapshot.debt;
    if (debt != null) _runReload(debt, reload: const ReloadToCurrentDepth());
  }

  /// Parks, restores or restarts the stream as [cacheAction] says. The feed it put back, or null when
  /// it started over.
  _NormalSnapshot<T>? _runCacheAction(CacheAction cacheAction) {
    final keptSnapshot = cacheAction == .restoreNormal ? _normalSnapshot : null;
    if (keptSnapshot == null) {
      if (cacheAction == .snapshotThenRefresh) _parkFeed();
      _startRun(.queryChanged, (run) => run.reset());
    } else {
      _restoreFeed(keptSnapshot);
    }

    return keptSnapshot;
  }

  /// Puts the feed aside while searching. Settled, since a restore re-fetches over both flags anyway.
  void _parkFeed() {
    final runningReload = _runningReload;
    _normalSnapshot = _NormalSnapshot(
      state: _pagingStateNotifier.value.settled(),
      signal: _lastPageSignal,
      // The restart strands a live run, so the feed inherits its ask.
      debt: runningReload != null && !runningReload.isStale ? runningReload.pendingAsk : null,
    );
  }

  /// Puts the feed kept while searching back.
  void _restoreFeed(_NormalSnapshot<T> snapshot) {
    _rowTransitionsNotifier.settle();
    _generation++;
    _lastFailedPageIndex = null;
    _lastPageSignal = snapshot.signal;
    _normalSnapshot = null;
    _pagingStateNotifier.value = snapshot.state;
    // Parked before its 1st page landed, so that page is still owed, unless a debt's reload fetches it
    // anyway.
    if (snapshot.state.status == .loadingFirstPage && snapshot.debt == null) {
      _startRun(.initialLoad, (run) => run.reset());
    }
  }

  /// Restarts the stream: invalidates in-flight writes, clears the end signal so a signal policy can't
  /// read the old stream's last one, and fetches the new 1st page, which reports [trigger].
  Future<void> _resetPaging(FetchTrigger trigger) {
    _rowTransitionsNotifier.settle();
    final generation = ++_generation;
    _lastFailedPageIndex = null;
    _lastPageSignal = null;
    _pagingStateNotifier.value = PagingState();

    // Once the current work is done, so a reload's events fire before its page is asked for, and resets
    // made in one go send one request.
    return Future.microtask(() async {
      if (generation == _generation) await _fetchNextPage(trigger: trigger);
    });
  }

  // The engine side of a reload, reached through a [_ReloadRun].

  /// Replaces the loaded pages with [pages] atomically, recording [lastSignal] as the new end signal.
  void _commit(List<LoadedPage<T>> pages, {Object? lastSignal}) {
    _generation++;
    _lastPageSignal = lastSignal;
    _pagingStateNotifier.value = PagingState(
      pages: pages,
      hasNextPage: _nextPageIndex(pages) != null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = widget.surfaces;

    final pagedList = TripleValueListenableBuilder(
      firstListenable: _pagingStateNotifier,
      secondListenable: _searchModeNotifier,
      // An edit only needs the rebuild, _displayFor reads the edits.
      thirdListenable: _editStoreNotifier,
      builder: (context, state, isSearchMode, _, _) => PagedView(
        state: _shownStateFor(state),
        onNearEnd: _onNearEnd,
        onRetry: _retryPage,
        itemBuilder: switch (widget.source.editTransition) {
          NoEditTransition() => widget.itemBuilder,
          AnimatedEditTransition(:final transitionBuilder) => _rowTransitionsNotifier.decorate(
            widget.itemBuilder,
            itemIdGetter: widget.source.itemIdGetter,
            transitionBuilder: transitionBuilder,
          ),
        },
        itemIdGetter: widget.source.itemIdGetter,
        grouping: widget.grouping,
        scrollConfig: widget.scrollConfig,
        refresh: widget.source.refresh,
        showsSurfaceGetter: _showsSurface,
        takesPullGetter: _takesPull,
        pullExtentListenable: _pullExtentNotifier,
        shouldKeepPosition: widget.source.shouldKeepPosition,
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
    );

    return switch (widget.source.refresh) {
      NoRefresh() => pagedList,
      PullToRefresh(:final indicatorBuilder, :final indicatorExtent) => RefreshBinding(
        onRefresh: _refreshFromPull,
        takesPullGetter: _takesPull,
        indicatorExtent: indicatorExtent,
        indicatorBuilder: indicatorBuilder,
        pullExtentNotifier: _pullExtentNotifier,
        child: pagedList,
      ),
    };
  }

  /// Reads the state as a drag starts, which can be a frame ahead of the screen.
  bool _takesPull() => widget.source.refresh.takesPull(_shownStatus());

  bool _showsSurface() => switch (_shownStatus()) {
    .loadingFirstPage || .firstPageError || .noItemsFound => true,
    .ongoing || .subsequentPageError || .completed => false,
  };

  PagingStatus _shownStatus() => _shownStateFor(_pagingStateNotifier.value).status;

  /// What the list shows of [state]. While it pages past an empty page, that's the loader, and the
  /// empty surface waits for the true end (or the maxPages give-up).
  PagingState<T> _shownStateFor(PagingState<T> state) =>
      _shouldAdvancePastEmpty(state) ? PagingState() : _displayFor(state).state;

  @override
  Future<void> refresh() => _runReload(.refresh).doneFuture;

  @override
  Future<void> invalidate() => _runReload(.invalidated).doneFuture;

  @override
  Future<void> reset() {
    widget.observer?.onReload(.invalidated);
    _normalSnapshot = null; // the kept feed starts over too: the restore falls through to page 0
    final doneFuture = _startRun(.invalidated, (run) => run.reset()).doneFuture;
    // After the run settles held exits, so none books into the fresh list.
    _editStoreNotifier.clear();

    return doneFuture;
  }

  /// Completes once the list shows fresh rows or its own loader, so the indicator never spins beside
  /// that loader.
  Future<void> _refreshFromPull() => _runReload(.refresh).handOverFuture;

  @override
  void upsert(T item) => _bookGrowingIn(item, () => _edit(item, item));

  @override
  Future<void> upsertAsync(
    T draft, {
    required Future<T> commit,
    void Function(Exception exception)? onFailure,
  }) async {
    final itemIdGetter = widget.source.itemIdGetter;
    final draftId = itemIdGetter(draft);
    final pendingEdit = _editStoreNotifier.pendingEdit(draftId, draft);
    final isNewRow = _bookGrowingIn(draft, pendingEdit.book);
    void rollBack() {
      // A create that didn't stick leaves like a remove.
      if (isNewRow && pendingEdit.isNewest) {
        _bookShrinkingOut(draft, pendingEdit.drop);
      } else {
        pendingEdit.drop();
      }
    }

    final T savedItem;
    try {
      savedItem = await commit;
      assert(
        itemIdGetter(savedItem) == draftId,
        "upsertAsync needs the saved item to keep the draft's id.",
      );
    } on Exception catch (exception) {
      rollBack();
      onFailure?.call(exception);

      return;
    } on Object {
      rollBack(); // an Error is a bug, so it goes on to the app after

      rethrow;
    }
    pendingEdit.settle(savedItem);
  }

  @override
  Future<void> removeAsync(
    T item, {
    required Future<void> commit,
    void Function(Exception exception)? onFailure,
  }) async {
    final pendingEdit = _editStoreNotifier.pendingEdit(widget.source.itemIdGetter(item), null);
    _bookShrinkingOut(item, pendingEdit.book);
    // Comes back like an upsert.
    void rollBack() => _bookGrowingIn(item, pendingEdit.drop);

    try {
      await commit;
    } on Exception catch (exception) {
      rollBack();
      onFailure?.call(exception);

      return;
    } on Object {
      rollBack(); // an Error is a bug, so it goes on to the app after

      rethrow;
    }
    pendingEdit.settle(null);
  }

  /// Whether [book] brought in a new row.
  bool _bookGrowingIn(T item, VoidCallback book) {
    final animation = _editAnimation;
    if (animation == null) {
      book();

      return false;
    }

    final id = widget.source.itemIdGetter(item);
    final wasShown = _isShown(id);
    book();
    final isNewRow = !wasShown && _isShown(id);
    _rowTransitionsNotifier.upsert(id, isNewRow: isNewRow, duration: animation.duration);

    return isNewRow;
  }

  @override
  void remove(T item) => _bookShrinkingOut(item, () => _edit(item, null));

  void _bookShrinkingOut(T item, VoidCallback book) {
    final animation = _editAnimation;
    final id = widget.source.itemIdGetter(item);
    if (animation == null || !_isShown(id)) {
      book();

      return;
    }

    _rowTransitionsNotifier.remove(
      id,
      bookRemoval: book,
      duration: animation.duration,
      axis: widget.scrollConfig.scrollDirection,
    );
  }

  /// The edit transition, unless there is none, the platform asks for less motion, or a save answered
  /// after the list was gone.
  AnimatedEditTransition? get _editAnimation => switch (widget.source.editTransition) {
    final AnimatedEditTransition transition
        when mounted && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false) =>
      transition,
    AnimatedEditTransition() || NoEditTransition() => null,
  };

  /// Whether the item with [id] has a row in what renders now.
  bool _isShown(Object id) => _displayFor(_pagingStateNotifier.value).shownIds.contains(id);

  void _edit(T item, T? editedItem) =>
      _editStoreNotifier.book(widget.source.itemIdGetter(item), editedItem);

  /// The one reload entry point, gesture or controller. Join and book rules: APPENDIX reload-run. [reload]
  /// overrides what [_reloadFor] would pick, for a restore paying its debt to depth.
  _ReloadRun<T> _runReload(FetchTrigger trigger, {Reload? reload}) {
    _normalSnapshot?.owe(trigger); // asked while searching, so the parked feed owes it too
    final runningReload = _runningReload;
    if (runningReload != null && !runningReload.isStale) {
      if (runningReload.trigger != .refresh || trigger != .refresh) {
        runningReload.rerunTrigger = _stronger(runningReload.rerunTrigger, trigger);
      }

      return runningReload;
    }

    return _startRun(trigger, (run) => (reload ?? _reloadFor(trigger)).run(run), announces: true);
  }

  /// Called directly it cuts in, since [_runReload] is where a caller meets the live run.
  _ReloadRun<T> _startRun(
    FetchTrigger trigger,
    Future<void> Function(_ReloadRun<T> run) work, {
    bool announces = false,
  }) {
    final run = _ReloadRun(this, trigger);
    _runningReload = run;
    if (announces) widget.observer?.onReload(trigger);
    unawaited(
      work(run).whenComplete(() {
        if (identical(_runningReload, run)) _runningReload = null;
        run.finish();
        final rerunTrigger = run.rerunTrigger;
        if (rerunTrigger != null && !run.isStale) _runReload(rerunTrigger);
      }),
    );

    return run;
  }

  /// A re-read keeps the user's place. A refresh does what the pull is configured to do, falling back
  /// to the pager's own reset when there is no gesture to read it off.
  Reload _reloadFor(FetchTrigger trigger) => switch (trigger) {
    .invalidated => const ReloadToCurrentDepth(),
    _ => switch (widget.source.refresh) {
      PullToRefresh(:final reload) => reload,
      NoRefresh() => const ResetToFirstPage(),
    },
  };
}

/// One run's handle onto the engine, the [ReloadContext] a [Reload] runs through.
///
/// One per run rather than the State itself, so a run knows its own facts: the trigger its pages
/// report, and whether the list moved on since it began.
final class _ReloadRun<T extends Object>(
  final _AsyncListViewState<T> _engine,

  /// What every page fetched through this run reports.
  final FetchTrigger trigger,
) implements ReloadContext<T> {
  final _doneCompleter = Completer<void>();
  final _handOverCompleter = Completer<void>();

  /// The generation this run belongs to. Its own writes move it along, so only another writer can make
  /// it stale.
  int _epoch = _engine._generation;

  /// Booked by a caller that met this run live and must not be lost. Runs once this one is done.
  FetchTrigger? rerunTrigger;

  /// Completes once the run finishes, committed or not, after the engine has let go of it.
  Future<void> get doneFuture => _doneCompleter.future;

  /// Completes once the list shows this run's result or its own loader, whichever comes 1st.
  Future<void> get handOverFuture => _handOverCompleter.future;

  /// What a caller asked of this run that cutting it off would lose: a booked rerun, or the run itself
  /// when a caller asked for it. A 1st-page load the engine started is nobody's ask.
  FetchTrigger? get pendingAsk => switch (trigger) {
    .refresh || .invalidated => _stronger(rerunTrigger, trigger),
    .initialLoad || .nextPage || .retry || .queryChanged => rerunTrigger,
  };

  @override
  bool get isStale => _engine._generation != _epoch;

  PagingState<T>? _startState;

  /// When each re-fetch went out.
  final _readStamps = <int, int>{};

  /// The signal each re-fetch went out with.
  final _previousSignals = <int, Object?>{};

  @override
  int get depth => (_startState ??= _engine._pagingStateNotifier.value).pages?.length ?? 0;

  @override
  bool get isSignalBased => _engine._signalKind.threadsSignal;

  @override
  Future<(List<T>, Object?)> fetch(int index, Object? previousSignal) {
    _readStamps[index] = _engine._editStoreNotifier.value;
    _previousSignals[index] = previousSignal;

    return _engine._fetchPageRaw(index, previousSignal, trigger);
  }

  @override
  Future<void> commit(List<List<T>> pages, {Object? lastSignal}) async {
    if (isStale) return;
    final source = _engine.widget.source;
    final rereadIndexes = resolveRereadIndexes(
      oldPages: (_startState?.pages ?? const []).map((page) => page.items),
      freshPages: pages,
      readStamps: _readStamps,
      removalStamps: _engine._removalStampsSince(_readStamps.values.min, pages.flattened),
      itemIdGetter: source.itemIdGetter,
      pageSize: source.pageSize,
    );
    final Map<int, List<T>> rereadItemsByIndex;
    if (rereadIndexes.isEmpty) {
      rereadItemsByIndex = const {};
    } else {
      try {
        // After every page landed, so each read sees whatever the pages either side of it saw.
        final rereads = await Future.wait(
          rereadIndexes.map(
            (index) => _engine._fetchPageRaw(index, _previousSignals[index], trigger),
          ),
          eagerError: true,
        );
        rereadItemsByIndex = Map.fromIterables(rereadIndexes, rereads.map((read) => read.$1));
      } on Exception {
        return; // the old list stays, the observer already saw the error
      }
      if (isStale) return;
    }

    _engine._commit(
      resolveLinedUpPages(
            freshPages: pages,
            rereadItemsByIndex: rereadItemsByIndex,
            itemIdGetter: source.itemIdGetter,
          )
          .mapIndexed(
            (index, items) => LoadedPage(
              items: items,
              readStamp: _readStamps[index]!, // every page came through [fetch]
              previousSignal: _previousSignals[index],
            ),
          )
          .toList(growable: false),
      lastSignal: lastSignal,
    );
    _epoch = _engine._generation;
  }

  @override
  Future<void> reset() {
    final firstPageFuture = _engine._resetPaging(trigger);
    _epoch = _engine._generation;
    _handOver(); // the loader shows from here

    return firstPageFuture;
  }

  /// Marks the run finished. The engine calls it once it has let go of the run.
  void finish() {
    _handOver();
    _doneCompleter.complete();
  }

  void _handOver() {
    if (!_handOverCompleter.isCompleted) _handOverCompleter.complete();
  }
}

/// The normal-mode stream parked while searching, put back as it was when the query clears.
final class _NormalSnapshot<T extends Object>({
  required final PagingState<T> state,

  /// The stream's last end signal, restored with [state] so a signal policy reads its own.
  required final Object? signal,

  /// An ask made while the feed sat here, paid by a re-read once it is put back.
  var FetchTrigger? debt,
}) {
  /// Books [trigger] against the feed. A refresh is never downgraded to a re-read.
  void owe(FetchTrigger trigger) => debt = _stronger(debt, trigger);
}

/// What renders, and the ids in it.
typedef _Display<T extends Object> = ({PagingState<T> state, Set<Object> shownIds});

/// The stronger of a [pending] ask and the [next] one: a refresh outranks a re-read.
FetchTrigger _stronger(FetchTrigger? pending, FetchTrigger next) =>
    pending == .refresh ? .refresh : next;
