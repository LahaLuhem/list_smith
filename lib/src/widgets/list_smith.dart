import 'package:flutter/widgets.dart';

import '../data/pagination/page_fetcher.dart';
import '../data/pagination/pagination_end_policy.dart';
import '../data/presentation/async_list_surfaces.dart';
import '../data/presentation/item_builder.dart';
import '../data/presentation/list_scroll_config.dart';
import '../data/presentation/no_results_builder.dart';
import '../data/search/sync_search_predicate.dart';
import '../data/source/list_source.dart';
import 'async_list_view.dart';
import 'sync_list_view.dart';

/// A developer-first list handling async pagination and pull-to-refresh, or sync in-memory search.
///
/// Wraps `ListView.builder` and owns the scrollable and any controller, so consumers pass a data
/// source, an [ItemBuilder], and config, never a `ListView` or a controller. Every visible surface
/// has a neutral, widgets-layer default, so the list drops into a Material, Cupertino, or bespoke
/// app without importing a look it never chose.
///
/// Build it with [ListSmith.async] (a paginated, pull-to-refresh list over a [PageFetcher]) or
/// [ListSmith.sync] (an in-memory list searched by a [SyncSearchPredicate]). Internally it is a
/// stateless dispatcher over a sealed [ListSource]: each named constructor builds one source case,
/// and [build] routes that case to the engine for it, so no parameter meant for one mode is ever
/// silently inert on another.
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

  /// The current search query for a `.sync` list; trimmed and gated by [minSearchLength].
  final String query;

  /// Minimum trimmed [query] length before a sync search runs; below it the query counts as empty.
  final int minSearchLength;

  /// How long to wait after [query] changes before a sync search filters; [Duration.zero] is
  /// immediate.
  final Duration searchDebounce;

  /// Builds the surface shown when a search matches nothing; null uses the neutral default.
  final NoResultsBuilder? noResultsBuilder;

  /// Scroll and layout configuration for the underlying scrollable.
  final ListScrollConfig scroll;

  /// Creates an async, paginated list driven by [fetchPage].
  ///
  /// [fetchPage] receives a 0-based page index and `pageSize` and returns one page of items;
  /// pagination ends per `endPolicy` (by default, the first empty page). [itemBuilder] renders each
  /// item. [surfaces] overrides the async-only neutral defaults; [emptyBuilder] and [scroll] apply to
  /// every list.
  ListSmith.async({
    required PageFetcher<T> fetchPage,
    required this.itemBuilder,
    int pageSize = 20,
    this.pullToRefresh = true,
    PaginationEndPolicy endPolicy = const StopOnEmptyPagesPolicy(),
    this.surfaces = const AsyncListSurfaces(),
    this.scroll = const ListScrollConfig(),
    this.emptyBuilder,
    this.separatorBuilder,
    super.key,
  }) : query = '',
       minSearchLength = 0,
       searchDebounce = .zero,
       noResultsBuilder = null,
       _source = AsyncSource(fetchPage: fetchPage, pageSize: pageSize, endPolicy: endPolicy);

  /// Creates a sync, in-memory searchable list over [items].
  ///
  /// [searchBy] decides whether an item matches the current [query]; it is required because a sync
  /// list is always about search (there is nothing to paginate or refresh over in-memory data). The
  /// query is trimmed, gated by [minSearchLength], and debounced by [searchDebounce] (immediate by
  /// default). [emptyBuilder] shows when [items] is empty and [noResultsBuilder] when a search
  /// matches nothing; both fall back to neutral defaults.
  ListSmith.sync({
    required Iterable<T> items,
    required SyncSearchPredicate<T> searchBy,
    required this.itemBuilder,
    this.query = '',
    this.minSearchLength = 0,
    this.searchDebounce = .zero,
    this.scroll = const ListScrollConfig(),
    this.emptyBuilder,
    this.noResultsBuilder,
    this.separatorBuilder,
    super.key,
  }) : pullToRefresh = true,
       surfaces = const AsyncListSurfaces(),
       _source = SyncSource(items: items, searchBy: searchBy);

  @override
  Widget build(BuildContext context) => switch (_source) {
    final AsyncSource<T> source => AsyncListView<T>(
      source: source,
      itemBuilder: itemBuilder,
      separatorBuilder: separatorBuilder,
      pullToRefresh: pullToRefresh,
      emptyBuilder: emptyBuilder,
      surfaces: surfaces,
      scroll: scroll,
    ),
    final SyncSource<T> source => SyncListView<T>(
      source: source,
      query: query,
      minSearchLength: minSearchLength,
      searchDebounce: searchDebounce,
      itemBuilder: itemBuilder,
      separatorBuilder: separatorBuilder,
      emptyBuilder: emptyBuilder,
      noResultsBuilder: noResultsBuilder,
      scroll: scroll,
    ),
  };
}
