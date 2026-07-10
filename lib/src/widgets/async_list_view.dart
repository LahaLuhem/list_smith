/// @docImport 'list_smith.dart';
library;

import 'package:flutter/widgets.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../data/pagination/pagination_end_policy.dart';
import '../data/pagination/pagination_end_policy_resolver.dart';
import '../data/presentation/async_list_surfaces.dart';
import '../data/presentation/item_builder.dart';
import '../data/presentation/list_scroll_config.dart';
import '../data/source/list_source.dart';
import 'paged_view.dart';
import 'refresh_binding.dart';

/// The async engine behind [ListSmith.async]: owns the paging controller lifecycle, wires
/// pull-to-refresh, and renders the paged list.
///
/// Unexported. [ListSmith] builds one of these for an [AsyncSource]. Split out from that dispatcher
/// so the async paging logic lives in one focused widget and the public widget stays a thin router
/// over the sealed source. Defaults are resolved by [ListSmith.async]; this widget re-declares none,
/// so a value is defined in exactly one place.
class AsyncListView<T extends Object> extends StatefulWidget {
  /// The async, paginated source of data and the policy deciding when it runs out.
  final AsyncSource<T> source;

  /// Builds the widget for each item.
  final ItemBuilder<T> itemBuilder;

  /// Builds the separator between items; null for no separators.
  final IndexedWidgetBuilder? separatorBuilder;

  /// Whether pull-to-refresh is enabled.
  final bool pullToRefresh;

  /// Builds the surface shown when the source yields no items; null uses the neutral default.
  final WidgetBuilder? emptyBuilder;

  /// The async-only override surfaces (page loading and error, end-of-list footer, refresh indicator).
  final AsyncListSurfaces surfaces;

  /// Scroll and layout configuration for the underlying scrollable.
  final ListScrollConfig scroll;

  /// Creates the async paged list around an [AsyncSource].
  const AsyncListView({
    required this.source,
    required this.itemBuilder,
    required this.pullToRefresh,
    required this.surfaces,
    required this.scroll,
    this.separatorBuilder,
    this.emptyBuilder,
    super.key,
  });

  @override
  State<AsyncListView<T>> createState() => _AsyncListViewState<T>();
}

class _AsyncListViewState<T extends Object> extends State<AsyncListView<T>> {
  late final _controller = PagingController<int, T>(
    getNextPageKey: (state) => _nextPageKey(state, widget.source.endPolicy),
    fetchPage: (pageKey) async =>
        (await widget.source.fetchPage(pageKey, widget.source.pageSize)).toList(growable: false),
  );

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = widget.surfaces;

    final list = PagingListener<int, T>(
      controller: _controller,
      builder: (_, state, fetchNextPage) => PagedView<T>(
        state: state,
        fetchNextPage: fetchNextPage,
        itemBuilder: widget.itemBuilder,
        scroll: widget.scroll,
        separatorBuilder: widget.separatorBuilder,
        firstPageLoadingBuilder: surfaces.firstPageLoadingBuilder,
        newPageLoadingBuilder: surfaces.newPageLoadingBuilder,
        firstPageErrorBuilder: surfaces.firstPageErrorBuilder,
        newPageErrorBuilder: surfaces.newPageErrorBuilder,
        emptyBuilder: widget.emptyBuilder,
        noMoreItemsBuilder: surfaces.noMoreItemsBuilder,
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

  final pageItemCounts = [for (final page in pages) page.length];
  if (endPolicy.hasReachedEnd(pageItemCounts)) return null;

  return pages.length;
}
