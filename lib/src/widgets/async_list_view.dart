/// @docImport '/src/data/pagination/models/empty_page_behaviour.dart';
/// @docImport '/src/data/search/models/search_cache_policy.dart';
/// @docImport 'list_smith.dart';
library;

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:multi_value_listenable_builder_typed/multi_value_listenable_builder_typed.dart';

import '/src/data/control/models/list_smith_controller.dart';
import '/src/data/control/models/list_smith_controller_host.dart';
import '/src/data/edits/models/edit_transition.dart';
import '/src/data/edits/typedefs/item_edit.dart';
import '/src/data/edits/utils/edit_resolver.dart';
import '/src/data/grouping/models/grouping.dart';
import '/src/data/observer/models/list_smith_observer.dart';
import '/src/data/pagination/enums/fetch_trigger.dart';
import '/src/data/pagination/enums/paging_status.dart';
import '/src/data/pagination/models/empty_page_context.dart';
import '/src/data/pagination/models/end_context.dart';
import '/src/data/pagination/models/loaded_page.dart';
import '/src/data/pagination/models/page_request.dart';
import '/src/data/pagination/models/paging_state.dart';
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
import 'row_transitions_notifier.dart';

/// The async engine behind [ListSmith.async]: owns the paging state and every fetch into it, wires
/// pull-to-refresh, and runs feed and search as 2 views on that one state.
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
  required final ListScrollConfig scroll,

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
  /// error on the paging state: a depth reload's commit clears that, and the page is still a retry.
  int? _lastFailedPageIndex;

  /// Whether a row near the end already booked the next page this frame.
  var _isNextPageBooked = false;

  /// Memo for [_displayFor], keyed on paging-state identity, the edit counter and the mode, so a rebuild
  /// that changes none of them skips the O(loaded) pass. One cell, so the parts can't drift.
  ({PagingState<T> raw, int editStamp, bool isSearchMode, _Display<T> display})? _displayMemo;

  /// The latest local edit per item id, oldest first. Beside the pages rather than in them, so the end
  /// policy and the reloads keep reading what the server sent.
  final _edits = <Object, ItemEdit<T>>{};

  /// Counts local edits.
  final _editStampNotifier = ValueNotifier<int>(0);

  /// Whether the controller currently reflects search results (drives the empty/no-results surface).
  late final ValueNotifier<bool> _searchModeNotifier;

  /// The run in flight, a reload or a 1st-page load, null when there is none.
  _ReloadRun<T>? _runningReload;

  /// The rows edits are animating. Idle unless the source has an [EditTransition].
  late final _rowTransitionsNotifier = RowTransitionsNotifier<T>(
    vsync: this,
    bookRemoval: (item) => _edit(item, null),
  );

  @override
  void initState() {
    super.initState();

    _debouncer.seed(widget.query);
    _searchModeNotifier = ValueNotifier(_isSearchQuery(_debouncer.committedQuery));
    _pagingStateNotifier
      ..addListener(_dropDeadEdits)
      ..addListener(_maybeAdvancePastEmptyPage);
    _editStampNotifier.addListener(_maybeAdvancePastEmptyPage);
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
    _editStampNotifier.dispose();
    _rowTransitionsNotifier.dispose();

    super.dispose();
  }

  bool _isSearchQuery(String query) => query.isNotEmpty && widget.source.supportsSearch;

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
    final readStamp = _editStampNotifier.value; // before the await, so a later edit is newer

    try {
      final (items, signal) = await _fetchPageRaw(
        pageIndex,
        _lastPageSignal,
        resolveTrigger(
          pageIndex: pageIndex,
          pending: trigger,
          lastFailedPageIndex: _lastFailedPageIndex,
        ),
      );
      if (generation != _generation) return;

      _lastPageSignal = signal;
      final latestState = _pagingStateNotifier.value;
      _pagingStateNotifier.value = latestState.copyWith(
        pages: [
          ...?latestState.pages,
          LoadedPage(items: items, readStamp: readStamp),
        ],
        isLoading: false,
      );
    } on Exception catch (error) {
      // Only Exceptions: an Error is a bug in the fetcher, so it goes on to the app and the list waits.
      if (generation == _generation) {
        _pagingStateNotifier.value = _pagingStateNotifier.value.failed(error);
      }
    }
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
        final AsyncSearch<T> asyncSearch when isSearchMode => await asyncSearch.fetchPage(
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
    } on Exception catch (error, stackTrace) {
      if (generation == _generation) _lastFailedPageIndex = pageKey;
      widget.observer?.onError(error, stackTrace);

      rethrow;
    }
  }

  /// The index of the page after [pages], which is their count, or null once [AsyncSource.endPolicy]
  /// reports the end.
  int? _nextPageIndex(List<LoadedPage<T>>? pages) {
    if (pages == null || pages.isEmpty) return 0;

    final endContext = EndContext(
      pageItemCounts: pages.map((page) => page.items.length).toList(growable: false),
      pageSize: widget.source.pageSize,
      lastPageSignal: _lastPageSignal,
    );

    return widget.source.endPolicy.hasReachedEnd(endContext) ? null : pages.length;
  }

  /// What renders, [state] with the local edits applied and overlap duplicates dropped, and the ids
  /// in it. The paging state's own pages stay raw, why in APPENDIX.md, `overlap-dedup`.
  _Display<T> _displayFor(PagingState<T> state) {
    final itemIdGetter = widget.source.itemIdGetter;
    final pages = state.pages;
    if (pages == null) return (state: state, shownIds: const {});

    final editStamp = _editStampNotifier.value;
    final isSearchMode = _searchModeNotifier.value;
    final displayMemo = _displayMemo;
    if (displayMemo != null &&
        identical(state, displayMemo.raw) &&
        displayMemo.editStamp == editStamp &&
        displayMemo.isSearchMode == isSearchMode) {
      return displayMemo.display;
    }

    final _Display<T> display;
    if (_edits.isEmpty) {
      // No edits keeps the plain de-dup pass, the one benchmark/micro/dedup_scaling.dart measures.
      final seenIds = <Object>{};
      display = (
        state: state.filterItems((item) => seenIds.add(itemIdGetter(item))),
        shownIds: seenIds,
      );
    } else {
      final (pages: displayPages, :shownIds) = resolveDisplayPages(
        pages: pages,
        edits: _edits,
        itemIdGetter: itemIdGetter,
        groupOf: widget.grouping.groupOf,
        acceptsNewItems: !isSearchMode, // only the server knows what matches the query
      );
      display = (state: state.copyWith(pages: displayPages), shownIds: shownIds);
    }
    _displayMemo = (raw: state, editStamp: editStamp, isSearchMode: isSearchMode, display: display);

    return display;
  }

  /// Forgets edits that every loaded and parked page was read after, since the server's copy has
  /// caught up.
  void _dropDeadEdits() {
    if (_edits.isEmpty) return;

    final readStamps = [
      ...?_pagingStateNotifier.value.pages,
      ...?_normalSnapshot?.state.pages,
    ].map((page) => page.readStamp);
    if (readStamps.isEmpty) return;

    final oldestRead = readStamps.min;
    // Nothing dropped here still shows, so no [_editStampNotifier] bump, which the display memo keys on.
    _edits.removeWhere((_, edit) => edit.stamp <= oldestRead);
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
    final wasEmptiedByEdits =
        isEmpty && (state.pages?.any((page) => page.items.isNotEmpty) ?? false);
    if (wasEmptiedByEdits && isMoreAvailable) return true;

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
    final search = widget.source.search;
    final cacheAction = switch (search) {
      final AsyncSearch<T> asyncSearch => asyncSearch.cachePolicy.actionFor(
        wasSearching: wasSearching,
        isSearching: isSearchMode,
      ),
      NoSearch() => CacheAction.refresh,
    };

    _searchModeNotifier.value = isSearchMode;
    final restoredSnapshot = _applyCacheAction(cacheAction);

    final observer = widget.observer;
    observer?.onQueryCommitted(committedQuery);
    if (wasSearching != isSearchMode) observer?.onSearchModeChanged(isSearchMode: isSearchMode);
    if (restoredSnapshot == null) observer?.onReload(.queryChanged); // reset, not restored
    // Paid after the query facts, so the observer's events stay in order.
    final debt = restoredSnapshot?.debt;
    if (debt != null) _runReload(debt, reload: const ReloadToCurrentDepth());
  }

  /// Applies [cacheAction]. Hands back the snapshot it put back, or null when the stream restarted.
  _NormalSnapshot<T>? _applyCacheAction(CacheAction cacheAction) {
    switch ((cacheAction, _normalSnapshot)) {
      case (.restoreNormal, final snapshot?):
        _rowTransitionsNotifier.settle();
        _generation++;
        _lastFailedPageIndex = null;
        _lastPageSignal = snapshot.signal;
        _normalSnapshot = null;
        _pagingStateNotifier.value = snapshot.state;
        // Parked before its 1st page landed, so that page is still owed, unless a debt's reload fetches
        // it anyway.
        if (snapshot.state.status == .loadingFirstPage && snapshot.debt == null) {
          _startRun(.initialLoad, (run) => run.reset());
        }

        return snapshot;
      case (.snapshotThenRefresh, _):
        // Snapshot the settled state. The re-fetch after a restore overwrites both flags anyway.
        final runningReload = _runningReload;
        final strandedTrigger = runningReload != null && !runningReload.isStale
            ? runningReload.pendingAsk
            : null;
        _normalSnapshot = _NormalSnapshot(
          state: _pagingStateNotifier.value.settled(),
          signal: _lastPageSignal,
          debt: strandedTrigger, // the reset below strands a live run, so the feed inherits its ask
        );
      case (.refresh, _) || (.restoreNormal, null):
      // Nothing to keep. The restart below is the whole action.
    }
    _startRun(.queryChanged, (run) => run.reset());

    return null;
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

  /// Whether the current stream's fetcher threads a per-page signal, which forces a sequential, atomic
  /// reload.
  bool get _isSignalBased => switch (widget.source.search) {
    final AsyncSearch<T> asyncSearch when _isSearchQuery(_debouncer.committedQuery) =>
      asyncSearch.fetchPage.reportsSignal,
    AsyncSearch<T>() || NoSearch() => widget.source.fetchPage.reportsSignal,
  };

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

    final pagedList = ValueListenableBuilder(
      valueListenable: _pagingStateNotifier,
      builder: (_, state, _) => DualValueListenableBuilder(
        firstListenable: _searchModeNotifier,
        secondListenable:
            _editStampNotifier, // an edit only needs the rebuild, _displayFor reads the edits
        builder: (context, isSearchMode, _, _) {
          // AdvanceToFirstNonEmpty pages past an empty page itself, so show loading while it does and
          // keep the empty surface for the true end (or the maxPages give-up).
          if (_shouldAdvancePastEmpty(state)) {
            return surfaces.firstPageLoadingBuilder?.call(context) ??
                const NeutralLoadingIndicator();
          }

          return PagedView(
            state: _displayFor(state).state,
            onNearEnd: _onNearEnd,
            onRetry: _retryPage,
            itemBuilder: switch (widget.source.editTransition) {
              AnimatedEditTransition(:final transitionBuilder) => _rowTransitionsNotifier.decorate(
                widget.itemBuilder,
                itemIdGetter: widget.source.itemIdGetter,
                transitionBuilder: transitionBuilder,
              ),
              NoEditTransition() => widget.itemBuilder,
            },
            itemIdGetter: widget.source.itemIdGetter,
            grouping: widget.grouping,
            scroll: widget.scroll,
            refresh: widget.source.refresh,
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
      NoRefresh() => pagedList,
      PullToRefresh(:final indicatorBuilder, :final indicatorExtent) => RefreshBinding(
        onRefresh: _refreshFromPull,
        takesPull: _takesPull,
        indicatorExtent: indicatorExtent,
        indicatorBuilder: indicatorBuilder,
        child: pagedList,
      ),
    };
  }

  /// Reads the state as a drag starts, which can be a frame ahead of the screen.
  bool _takesPull() => widget.source.refresh.takesPull(_shownStatus());

  /// What the list shows, the loader included while it pages past an empty page.
  PagingStatus _shownStatus() {
    final state = _pagingStateNotifier.value;

    return _shouldAdvancePastEmpty(state) ? .loadingFirstPage : _displayFor(state).state.status;
  }

  @override
  Future<void> refresh() => _runReload(.refresh).doneFuture;

  @override
  Future<void> invalidate() => _runReload(.invalidated).doneFuture;

  @override
  Future<void> reset() {
    widget.observer?.onReload(.invalidated);
    _normalSnapshot = null; // the kept feed starts over too: the restore falls through to page 0

    return _startRun(.invalidated, (run) => run.reset()).doneFuture;
  }

  /// Completes once the list shows fresh rows or its own loader, so the indicator never spins beside
  /// that loader.
  Future<void> _refreshFromPull() => _runReload(.refresh).handOverFuture;

  @override
  void upsert(T item) {
    final animation = _editAnimation;
    if (animation == null) {
      _edit(item, item);

      return;
    }

    final id = widget.source.itemIdGetter(item);
    final wasShown = _isShown(id);
    _edit(item, item);
    _rowTransitionsNotifier.upsert(
      id,
      isNewRow: !wasShown && _isShown(id),
      duration: animation.duration,
    );
  }

  @override
  void remove(T item) {
    final animation = _editAnimation;
    final id = widget.source.itemIdGetter(item);
    if (animation == null || !_isShown(id)) {
      _edit(item, null);

      return;
    }

    _rowTransitionsNotifier.remove(
      id,
      item,
      duration: animation.duration,
      axis: widget.scroll.scrollDirection,
    );
  }

  /// The edit transition, unless there is none or the platform asks for less motion.
  AnimatedEditTransition? get _editAnimation => switch (widget.source.editTransition) {
    final AnimatedEditTransition transition
        when !(MediaQuery.maybeDisableAnimationsOf(context) ?? false) =>
      transition,
    AnimatedEditTransition() || NoEditTransition() => null,
  };

  /// Whether the item with [id] has a row in what renders now.
  bool _isShown(Object id) => _displayFor(_pagingStateNotifier.value).shownIds.contains(id);

  /// Books [editedItem] against [item]'s id, null for a removal.
  void _edit(T item, T? editedItem) {
    final id = widget.source.itemIdGetter(item);
    final stamp = _editStampNotifier.value + 1;
    _edits
      ..remove(id) // re-booked at the end, so the newest new item lands on top
      ..[id] = (item: editedItem, stamp: stamp);
    _editStampNotifier.value = stamp;
  }

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

  /// What this run started from, for the pages a best-effort commit keeps.
  PagingState<T>? _startState;

  /// When each re-fetch went out.
  final _readStamps = <int, int>{};

  @override
  List<List<T>> get loadedPages =>
      ((_startState ??= _engine._pagingStateNotifier.value).pages ?? const [])
          .map((page) => page.items)
          .toList(growable: false);

  @override
  bool get isSignalBased => _engine._isSignalBased;

  @override
  Future<(List<T>, Object?)> fetch(int index, Object? previousSignal) {
    _readStamps[index] = _engine._editStampNotifier.value;

    return _engine._fetchPageRaw(index, previousSignal, trigger);
  }

  @override
  void commit(List<List<T>> pages, {Object? lastSignal}) {
    if (isStale) return;
    final startPages = _startState?.pages ?? const [];
    // A page whose re-fetch failed is the old one, handed back as is, so it keeps its old stamp. Every
    // other page came through [fetch].
    final committedPages = pages
        .mapIndexed(
          (index, items) => index < startPages.length && identical(items, startPages[index].items)
              ? startPages[index]
              : LoadedPage(items: items, readStamp: _readStamps[index]!),
        )
        .toList(growable: false);
    _engine._commit(committedPages, lastSignal: lastSignal);
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
