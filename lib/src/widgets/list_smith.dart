import 'package:flutter/widgets.dart';

import '../data/pagination/page_fetcher.dart';
import '../data/pagination/pagination_end_policy.dart';
import '../data/presentation/async_list_surfaces.dart';
import '../data/presentation/item_builder.dart';
import '../data/presentation/list_scroll_config.dart';
import '../data/source/list_source.dart';
import 'async_list_view.dart';

/// A developer-first list handling async pagination and pull-to-refresh.
///
/// Wraps `ListView.builder` and owns the scrollable and the paging controller, so consumers pass a
/// [PageFetcher], an [ItemBuilder], and config, never a `ListView` or a controller.
/// Every visible surface has a neutral, widgets-layer default, so the list drops into a Material,
/// Cupertino, or bespoke app without importing a look it never chose.
///
/// Build it with [ListSmith.async]. Internally it is a stateless dispatcher over a sealed
/// [ListSource]: each named constructor builds one source case, and [build] routes that case to the
/// engine for it, so no parameter meant for one mode is ever silently inert on another.
class ListSmith<T extends Object> extends StatelessWidget {
  final ListSource<T> _source;

  /// Builds the widget for each item.
  final ItemBuilder<T> itemBuilder;

  /// Builds the separator between items; null for no separators.
  final IndexedWidgetBuilder? separatorBuilder;

  /// Whether pull-to-refresh is enabled. When false, no refresh gesture is wired and the refresh
  /// builder in [surfaces] has no effect.
  final bool pullToRefresh;

  /// Builds the surface shown when the source yields no items; null uses the neutral default.
  ///
  /// Lives on the constructor rather than in [surfaces] because every list has an empty state, so it
  /// reads the same whichever constructor built the list.
  final WidgetBuilder? emptyBuilder;

  /// The async-only override surfaces (page loading and error, end-of-list footer, refresh indicator).
  final AsyncListSurfaces surfaces;

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
  }) : _source = AsyncSource(fetchPage: fetchPage, pageSize: pageSize, endPolicy: endPolicy);

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
  };
}
