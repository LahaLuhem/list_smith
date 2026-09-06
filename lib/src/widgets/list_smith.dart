/// @docImport '/src/data/pagination/models/page_request.dart';
library;

import 'package:flutter/widgets.dart';

import '/src/data/control/models/list_smith_controller.dart';
import '/src/data/grouping/models/grouping.dart';
import '/src/data/observer/models/list_smith_observer.dart';
import '/src/data/pagination/models/empty_page_behaviour.dart';
import '/src/data/pagination/models/page_fetcher.dart';
import '/src/data/pagination/models/pagination_end_policy.dart';
import '/src/data/pagination/typedefs/item_id.dart';
import '/src/data/presentation/models/async_list_surfaces.dart';
import '/src/data/presentation/models/list_scroll_config.dart';
import '/src/data/presentation/typedefs/item_builder.dart';
import '/src/data/presentation/typedefs/no_results_builder.dart';
import '/src/data/refresh/models/refresh.dart';
import '/src/data/search/models/search.dart';
import '/src/data/search/typedefs/sync_search_predicate.dart';
import '/src/data/source/list_source.dart';
import 'async_list_view.dart';
import 'sync_list_view.dart';

/// A developer-first list handling async pagination and pull-to-refresh, or sync in-memory search.
///
/// Wraps `ListView.builder` and owns the scrollable and the pager, so you pass a data source, an
/// [ItemBuilder], and config, never a `ListView` or a paging controller. Every visible surface has a
/// neutral widgets-layer default, so the list drops into a Material, Cupertino, or bespoke app
/// without dragging in a look you didn't choose.
///
/// [ListSmith.async] paginates over a [PageFetcher], and searches too when given an [AsyncSearch].
/// [ListSmith.sync] filters an in-memory list with a [SyncSearchPredicate]. Each constructor builds
/// one case of a sealed [ListSource] that [build] routes to its engine, so a parameter meant for one
/// mode is never silently inert on the other.
class ListSmith<T extends Object> extends StatelessWidget {
  final ListSource<T> _source;

  /// Builds the widget for each item.
  final ItemBuilder<T> itemBuilder;

  /// Builds the separator between items. Null for none.
  final IndexedWidgetBuilder? separatorBuilder;

  /// Builds the surface shown when the source yields no items. Null uses the neutral default. On the
  /// constructor rather than in [surfaces] because every list has an empty state.
  final WidgetBuilder? emptyBuilder;

  /// The async-only override surfaces (page loading and error, end-of-list footer, refresh
  /// indicator).
  final AsyncListSurfaces surfaces;

  /// Lifecycle events for logging or telemetry. Null is silent. Async only, like [surfaces].
  final ListSmithObserver? observer;

  /// Handle for refreshing the list from code. Null leaves refresh gesture-only. Async only.
  final ListSmithController? controller;

  /// The current search query, yours to own and pass in. Trimmed, then gated by [minSearchLength].
  final String query;

  /// Minimum trimmed [query] length before a search runs. Below it the query counts as empty.
  final int minSearchLength;

  /// How long to wait after [query] changes before it takes effect. [Duration.zero] is immediate.
  final Duration searchDebounce;

  /// Builds the surface shown when a search matches nothing. Null uses the neutral default.
  final NoResultsBuilder? noResultsBuilder;

  /// Scroll and layout configuration for the underlying scrollable.
  final ListScrollConfig scroll;

  /// Splits the list into sections. [NoGrouping] (the default) renders it flat. See [Grouping.by].
  final Grouping<T> grouping;

  /// Creates an async, paginated list driven by [fetchPage], optionally searchable via [search].
  ///
  /// [fetchPage] gets a [PageRequest] and returns that page's items. Only it and [itemBuilder] are
  /// required. The rest default to a 20-item page, pull-to-refresh on, pagination ending at the
  /// first empty page, no search, no grouping, and list_smith's own neutral surfaces. Each optional
  /// parameter's own type documents what it does.
  ///
  /// Two pairings are asserted: a non-empty [query] needs an [AsyncSearch], and a signal-reading
  /// end policy needs `withSignal` fetchers on both the feed and the search.
  new async({
    required PageFetcher<T> fetchPage,
    required this.itemBuilder,
    int pageSize = 20,
    Refresh refresh = const PullToRefresh(),
    PaginationEndPolicy endPolicy = const StopOnEmptyPagesPolicy(),
    EmptyPageBehaviour onEmptyPage = const ShowEmptySurface(),
    ItemId<T>? itemId,
    Search<T> search = const NoSearch(),
    this.query = '',
    this.minSearchLength = 0,
    this.searchDebounce = const Duration(milliseconds: 300),
    this.surfaces = const AsyncListSurfaces(),
    this.scroll = const ListScrollConfig(),
    Grouping<T>? grouping,
    this.emptyBuilder,
    this.noResultsBuilder,
    this.observer,
    this.controller,
    this.separatorBuilder,
    super.key,
  }) : assert(
         search is AsyncSearch<T> || query.isEmpty,
         'A query was set without search; pass search: AsyncSearch(...) to enable it.',
       ),
       assert(
         !endPolicy.requiresSignal || fetchPage.reportsSignal,
         'This end policy needs a signal-reporting fetcher. Build fetchPage with PageFetcher.withSignal.',
       ),
       assert(
         !endPolicy.requiresSignal || search is! AsyncSearch<T> || search.fetchPage.reportsSignal,
         'This end policy needs a signal-reporting search fetcher. Build the AsyncSearch fetcher with SearchPageFetcher.withSignal.',
       ),
       grouping = grouping ?? NoGrouping<T>(),
       _source = AsyncSource(
         fetchPage: fetchPage,
         pageSize: pageSize,
         endPolicy: endPolicy,
         onEmptyPage: onEmptyPage,
         refresh: refresh,
         search: search,
         itemId: itemId,
       );

  /// Creates a sync, in-memory searchable list over [items].
  ///
  /// [searchBy] is required: there is nothing to paginate or refresh over in-memory data, so search
  /// is the whole point. [searchDebounce] defaults to zero here, an in-memory filter being instant.
  new sync({
    required Iterable<T> items,
    required SyncSearchPredicate<T> searchBy,
    required this.itemBuilder,
    this.query = '',
    this.minSearchLength = 0,
    this.searchDebounce = .zero,
    this.scroll = const ListScrollConfig(),
    Grouping<T>? grouping,
    this.emptyBuilder,
    this.noResultsBuilder,
    this.separatorBuilder,
    super.key,
  }) : surfaces = const AsyncListSurfaces(),
       observer = null,
       controller = null,
       grouping = grouping ?? NoGrouping<T>(),
       _source = SyncSource(items: items, searchBy: searchBy);

  @override
  Widget build(BuildContext context) => switch (_source) {
    final AsyncSource<T> source => AsyncListView<T>(
      source: source,
      itemBuilder: itemBuilder,
      grouping: grouping,
      separatorBuilder: separatorBuilder,
      query: query,
      minSearchLength: minSearchLength,
      searchDebounce: searchDebounce,
      emptyBuilder: emptyBuilder,
      noResultsBuilder: noResultsBuilder,
      surfaces: surfaces,
      scroll: scroll,
      observer: observer,
      controller: controller,
    ),
    final SyncSource<T> source => SyncListView<T>(
      source: source,
      query: query,
      minSearchLength: minSearchLength,
      searchDebounce: searchDebounce,
      itemBuilder: itemBuilder,
      grouping: grouping,
      separatorBuilder: separatorBuilder,
      emptyBuilder: emptyBuilder,
      noResultsBuilder: noResultsBuilder,
      scroll: scroll,
    ),
  };
}
