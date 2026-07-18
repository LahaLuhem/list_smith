import 'package:flutter/widgets.dart';

import '/src/data/grouping/models/grouping.dart';
import '/src/data/observer/models/list_smith_observer.dart';
import '/src/data/pagination/models/page_fetcher.dart';
import '/src/data/pagination/models/pagination_end_policy.dart';
import '/src/data/pagination/typedefs/item_id.dart';
import '/src/data/presentation/models/async_list_surfaces.dart';
import '/src/data/presentation/models/list_scroll_config.dart';
import '/src/data/presentation/typedefs/item_builder.dart';
import '/src/data/presentation/typedefs/no_results_builder.dart';
import '/src/data/search/models/search_cache_policy.dart';
import '/src/data/search/models/search_page_fetcher.dart';
import '/src/data/search/typedefs/sync_search_predicate.dart';
import '/src/data/source/list_source.dart';
import 'async_list_view.dart';
import 'sync_list_view.dart';

/// A developer-first list handling async pagination and pull-to-refresh, or sync in-memory search.
///
/// Wraps `ListView.builder` and owns the scrollable and any controller, so consumers pass a data
/// source, an [ItemBuilder], and config, never a `ListView` or a controller. Every visible surface
/// has a neutral, widgets-layer default, so the list drops into a Material, Cupertino, or bespoke
/// app without importing a look it never chose.
///
/// Build it with [ListSmith.async] (a paginated, pull-to-refresh list over a [PageFetcher], made
/// searchable by also passing a [SearchPageFetcher]) or [ListSmith.sync] (an in-memory list searched
/// by a [SyncSearchPredicate]). Internally it is a stateless dispatcher over a sealed [ListSource]:
/// each named constructor builds one source case, and [build] routes that case to the engine for it,
/// so no parameter meant for one mode is ever silently inert on another.
class ListSmith<T extends Object> extends StatelessWidget {
  final ListSource<T> _source;

  /// Builds the widget for each item.
  final ItemBuilder<T> itemBuilder;

  /// Builds the separator between items; null for no separators.
  final IndexedWidgetBuilder? separatorBuilder;

  /// Whether pull-to-refresh is enabled (async only). When false, no refresh gesture is wired and
  /// the refresh builder in [surfaces] has no effect.
  final bool pullToRefresh;

  /// Builds the surface shown when the source yields no items; null uses the neutral default.
  ///
  /// Lives on the constructor rather than in [surfaces] because every list has an empty state, so it
  /// reads the same whichever constructor built the list.
  final WidgetBuilder? emptyBuilder;

  /// The async-only override surfaces (page loading and error, end-of-list footer, refresh
  /// indicator).
  final AsyncListSurfaces surfaces;

  /// Optional lifecycle observer for the async list (page loads, errors, refresh, search), for
  /// logging or telemetry; null is silent. Async-only, like [surfaces]: `.sync` exposes no observer.
  final ListSmithObserver? observer;

  /// The current search query, owned and passed in by the consumer; trimmed and gated by
  /// [minSearchLength]. Drives sync filtering, and async search when a search fetcher is provided.
  final String query;

  /// Minimum trimmed [query] length before a search runs; below it the query counts as empty.
  final int minSearchLength;

  /// How long to wait after [query] changes before it takes effect; [Duration.zero] is immediate.
  final Duration searchDebounce;

  /// Builds the surface shown when a search matches nothing; null uses the neutral default.
  final NoResultsBuilder? noResultsBuilder;

  /// Scroll and layout configuration for the underlying scrollable.
  final ListScrollConfig scroll;

  /// Splits the list into sections; [NoGrouping] (the default) renders a flat list. On the sync path
  /// the visible items are bucketed into contiguous groups; on the async path each page must already
  /// arrive ordered by group key. See [Grouping.by].
  final Grouping<T> grouping;

  /// Creates an async, paginated list driven by [fetchPage], optionally searchable via [searchFetchPage].
  ///
  /// [fetchPage] receives a 0-based page index and `pageSize` and returns one page of items;
  /// pagination ends per `endPolicy` (by default, the first empty page). Pass [itemId] to de-duplicate
  /// items across overlapping pages (e.g. an offset-based source whose data shifts between fetches);
  /// without it, overlapping pages render the item once per page, as the underlying pager does no
  /// de-duplication. Passing [searchFetchPage] opts into search: a non-empty [query] switches to a
  /// search view fetched by it, and [searchCachePolicy] governs how the normal list carries across that
  /// switch. [itemBuilder] renders each item; [surfaces] overrides the async-only neutral defaults;
  /// [emptyBuilder], [noResultsBuilder], and [scroll] apply to every list. Pass [observer] to receive
  /// lifecycle events (page loads, errors, refresh, search) for logging or telemetry. [grouping]
  /// optionally shows the items in sections (see [Grouping.by]).
  ListSmith.async({
    required PageFetcher<T> fetchPage,
    required this.itemBuilder,
    int pageSize = 20,
    this.pullToRefresh = true,
    PaginationEndPolicy endPolicy = const StopOnEmptyPagesPolicy(),
    ItemId<T>? itemId,
    SearchPageFetcher<T>? searchFetchPage,
    SearchCachePolicy searchCachePolicy = const ReplaceCachePolicy(),
    this.query = '',
    this.minSearchLength = 0,
    this.searchDebounce = const Duration(milliseconds: 300),
    this.surfaces = const AsyncListSurfaces(),
    this.scroll = const ListScrollConfig(),
    Grouping<T>? grouping,
    this.emptyBuilder,
    this.noResultsBuilder,
    this.observer,
    this.separatorBuilder,
    super.key,
  }) : assert(
         searchFetchPage != null || query.isEmpty,
         'A query was set without a searchFetchPage; pass searchFetchPage to enable search.',
       ),
       assert(
         endPolicy is! ExplicitHasMorePolicy || fetchPage.reportsSignal,
         'ExplicitHasMorePolicy needs a signal-reporting fetcher. Build fetchPage with PageFetcher.withSignal.',
       ),
       assert(
         endPolicy is! ExplicitHasMorePolicy || (searchFetchPage?.reportsSignal ?? true),
         'ExplicitHasMorePolicy needs a signal-reporting search fetcher. Build searchFetchPage with SearchPageFetcher.withSignal.',
       ),
       grouping = grouping ?? NoGrouping<T>(),
       _source = AsyncSource(
         fetchPage: fetchPage,
         pageSize: pageSize,
         endPolicy: endPolicy,
         searchCachePolicy: searchCachePolicy,
         searchFetchPage: searchFetchPage,
         itemId: itemId,
       );

  /// Creates a sync, in-memory searchable list over [items].
  ///
  /// [searchBy] decides whether an item matches the current [query]; it is required because a sync
  /// list is always about search (there is nothing to paginate or refresh over in-memory data). The
  /// query is trimmed, gated by [minSearchLength], and debounced by [searchDebounce] (immediate by
  /// default). [emptyBuilder] shows when [items] is empty and [noResultsBuilder] when a search
  /// matches nothing; both fall back to neutral defaults. [grouping] optionally shows the items in
  /// sections (see [Grouping.by]).
  ListSmith.sync({
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
  }) : pullToRefresh = true,
       surfaces = const AsyncListSurfaces(),
       observer = null,
       grouping = grouping ?? NoGrouping<T>(),
       _source = SyncSource(items: items, searchBy: searchBy);

  @override
  Widget build(BuildContext context) => switch (_source) {
    final AsyncSource<T> source => AsyncListView<T>(
      source: source,
      itemBuilder: itemBuilder,
      grouping: grouping,
      separatorBuilder: separatorBuilder,
      pullToRefresh: pullToRefresh,
      query: query,
      minSearchLength: minSearchLength,
      searchDebounce: searchDebounce,
      emptyBuilder: emptyBuilder,
      noResultsBuilder: noResultsBuilder,
      surfaces: surfaces,
      scroll: scroll,
      observer: observer,
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
