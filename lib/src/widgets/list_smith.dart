import 'package:flutter/widgets.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../data/pagination/page_fetcher.dart';
import '../data/pagination/pagination_end_policy.dart';
import '../data/pagination/pagination_end_policy_resolver.dart';
import '../data/presentation/error_builder.dart';
import '../data/presentation/item_builder.dart';
import '../data/presentation/list_scroll_config.dart';
import '../data/refresh/list_smith_refresh_state.dart';
import '../data/source/list_source.dart';
import 'paged_view.dart';
import 'refresh_binding.dart';

/// A developer-first list handling async pagination and pull-to-refresh.
///
/// Wraps `ListView.builder` and owns the scrollable and the paging controller, so consumers pass a
/// [PageFetcher], an [ItemBuilder], and config, never a `ListView` or a controller.
/// Every visible surface has a neutral, widgets-layer default, so the list drops into a Material,
/// Cupertino, or bespoke app without importing a look it never chose.
///
/// Build it with [ListSmith.async].
class ListSmith<T extends Object> extends StatefulWidget {
  final ListSource<T> _source;

  /// Builds the widget for each item.
  final ItemBuilder<T> itemBuilder;

  /// Builds the separator between items; null for no separators.
  final IndexedWidgetBuilder? separatorBuilder;

  /// Whether pull-to-refresh is enabled. When false, no refresh gesture is wired and [refreshBuilder]
  /// has no effect.
  final bool pullToRefresh;

  /// Draws the pull-to-refresh indicator; null uses the neutral default.
  final RefreshBuilder? refreshBuilder;

  /// Builds the first-page loading surface; null uses the neutral default.
  final WidgetBuilder? firstPageLoadingBuilder;

  /// Builds the new-page loading footer; null uses the neutral default.
  final WidgetBuilder? newPageLoadingBuilder;

  /// Builds the first-page error surface; null uses the neutral default.
  final ErrorBuilder? firstPageErrorBuilder;

  /// Builds the new-page error footer; null uses the neutral default.
  final ErrorBuilder? newPageErrorBuilder;

  /// Builds the surface shown when the source yields no items; null uses the neutral default.
  final WidgetBuilder? emptyBuilder;

  /// Builds the footer shown once every page has loaded; null uses the neutral default.
  final WidgetBuilder? noMoreItemsBuilder;

  /// Scroll and layout configuration for the underlying scrollable.
  final ListScrollConfig scroll;

  /// Creates an async, paginated list driven by [fetchPage].
  ///
  /// [fetchPage] receives a 0-based page index and `pageSize` and returns one page of items;
  /// pagination ends per `endPolicy` (by default, the first empty page). [itemBuilder] renders each item.
  /// The remaining parameters override the neutral default surfaces and the scroll configuration.
  ListSmith.async({
    required PageFetcher<T> fetchPage,
    required this.itemBuilder,
    super.key,
    int pageSize = 20,
    PaginationEndPolicy endPolicy = const StopOnEmptyPages(),
    this.separatorBuilder,
    this.pullToRefresh = true,
    this.refreshBuilder,
    this.firstPageLoadingBuilder,
    this.newPageLoadingBuilder,
    this.firstPageErrorBuilder,
    this.newPageErrorBuilder,
    this.emptyBuilder,
    this.noMoreItemsBuilder,
    this.scroll = const ListScrollConfig(),
  }) : _source = AsyncSource(fetchPage: fetchPage, pageSize: pageSize, endPolicy: endPolicy);

  @override
  State<ListSmith<T>> createState() => _ListSmithState<T>();
}

class _ListSmithState<T extends Object> extends State<ListSmith<T>> {
  late final AsyncSource<T> _source = switch (widget._source) {
    final AsyncSource<T> source => source,
  };

  late final _controller = PagingController<int, T>(
    getNextPageKey: (state) => _nextPageKey(state, _source.endPolicy),
    fetchPage: (pageKey) async =>
        (await _source.fetchPage(pageKey, _source.pageSize)).toList(growable: false),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() => Future.sync(_controller.refresh);

  @override
  Widget build(BuildContext context) {
    final list = PagingListener<int, T>(
      controller: _controller,
      builder: (_, state, fetchNextPage) => PagedView<T>(
        state: state,
        fetchNextPage: fetchNextPage,
        itemBuilder: widget.itemBuilder,
        scroll: widget.scroll,
        separatorBuilder: widget.separatorBuilder,
        firstPageLoadingBuilder: widget.firstPageLoadingBuilder,
        newPageLoadingBuilder: widget.newPageLoadingBuilder,
        firstPageErrorBuilder: widget.firstPageErrorBuilder,
        newPageErrorBuilder: widget.newPageErrorBuilder,
        emptyBuilder: widget.emptyBuilder,
        noMoreItemsBuilder: widget.noMoreItemsBuilder,
      ),
    );

    if (!widget.pullToRefresh) return list;

    return RefreshBinding(
      onRefresh: _onRefresh,
      refreshBuilder: widget.refreshBuilder,
      child: list,
    );
  }
}

/// Computes the next 0-based page key for [state], or `null` once [endPolicy] reports the end.
/// Keys are the page count so far, so they stay 0-based and sequential.
int? _nextPageKey<T extends Object>(PagingState<int, T> state, PaginationEndPolicy endPolicy) {
  final pages = state.pages;
  if (pages == null || pages.isEmpty) return 0;

  final pageItemCounts = [for (final page in pages) page.length];
  if (endPolicy.hasReachedEnd(pageItemCounts)) return null;

  return pages.length;
}
