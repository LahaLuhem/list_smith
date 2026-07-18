/// @docImport 'list_smith.dart';
library;

import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/widgets.dart';

import '/src/data/grouping/models/grouping.dart';
import '/src/data/presentation/models/list_scroll_config.dart';
import '/src/data/presentation/typedefs/item_builder.dart';
import '/src/data/presentation/typedefs/no_results_builder.dart';
import '/src/data/search/utils/sync_search_resolver.dart';
import '/src/data/source/list_source.dart';
import '/src/utils/query_debouncer.dart';
import 'defaults/neutral_empty_indicator.dart';
import 'defaults/neutral_no_results_indicator.dart';

/// The sync engine behind [ListSmith.sync]: filters an in-memory [SyncSource] by the debounced query
/// and renders it with a plain widgets-layer `ListView`.
///
/// Unexported. [ListSmith] builds one of these for a [SyncSource]. There is no paging controller or
/// pull-to-refresh (an in-memory list has nothing to page or refresh); the only moving part is the
/// query, which is trimmed, min-length-gated, and debounced before it filters. The source list is
/// materialised once (redone only when the source's items change) and the filtered, optionally
/// grouped result is held in a [ValueNotifier], so only the list subtree rebuilds when it changes.
/// Defaults are resolved by [ListSmith.sync]; this widget re-declares none.
class SyncListView<T extends Object> extends StatefulWidget {
  /// The in-memory source: the items and the predicate that filters them.
  final SyncSource<T> source;

  /// The current search query, owned and passed in by the consumer.
  final String query;

  /// Minimum trimmed query length before a search runs; below it the query counts as empty.
  final int minSearchLength;

  /// How long to wait after [query] changes before filtering; [Duration.zero] filters at once.
  final Duration searchDebounce;

  /// Builds the widget for each item.
  final ItemBuilder<T> itemBuilder;

  /// Splits the visible items into sections; [NoGrouping] (the default) renders a flat list.
  final Grouping<T> grouping;

  /// Builds the separator between items; null for no separators.
  final IndexedWidgetBuilder? separatorBuilder;

  /// Builds the surface shown when the source has no items; null uses the neutral default.
  final WidgetBuilder? emptyBuilder;

  /// Builds the surface shown when a search matches nothing; null uses the neutral default.
  final NoResultsBuilder? noResultsBuilder;

  /// Scroll and layout configuration for the underlying scrollable.
  final ListScrollConfig scroll;

  /// Creates the sync search list around a [SyncSource].
  const SyncListView({
    required this.source,
    required this.query,
    required this.minSearchLength,
    required this.searchDebounce,
    required this.itemBuilder,
    required this.grouping,
    required this.scroll,
    this.separatorBuilder,
    this.emptyBuilder,
    this.noResultsBuilder,
    super.key,
  });

  @override
  State<SyncListView<T>> createState() => _SyncListViewState<T>();
}

class _SyncListViewState<T extends Object> extends State<SyncListView<T>> {
  late final _debouncer = QueryDebouncer(onCommitted: _onQueryCommitted);
  late final ValueNotifier<({List<T> visibleItems, bool isSearching})> _resultNotifier;
  late List<T> _items;

  @override
  void initState() {
    super.initState();

    _debouncer.seed(widget.query);
    _items = widget.source.items.toList(growable: false);
    _resultNotifier = ValueNotifier(_resolve());
  }

  @override
  void didUpdateWidget(SyncListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    final itemsChanged = !identical(widget.source.items, oldWidget.source.items);
    if (itemsChanged) _items = widget.source.items.toList(growable: false);
    if (itemsChanged || !identical(widget.grouping, oldWidget.grouping)) {
      _resultNotifier.value = _resolve();
    }

    if (widget.query != oldWidget.query) _debouncer.schedule(widget.query, widget.searchDebounce);
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _resultNotifier.dispose();

    super.dispose();
  }

  ({List<T> visibleItems, bool isSearching}) _resolve() {
    final search = resolveSyncSearch(
      _items,
      widget.source.searchBy,
      _debouncer.committedQuery,
      widget.minSearchLength,
    );

    return (
      visibleItems: widget.grouping.arrange(search.visibleItems),
      isSearching: search.isSearching,
    );
  }

  void _onQueryCommitted(String committedQuery) => _resultNotifier.value = _resolve();

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: _resultNotifier,
    builder: (context, result, _) {
      if (_items.isEmpty) {
        return widget.emptyBuilder?.call(context) ?? const NeutralEmptyIndicator();
      }

      if (result.isSearching && result.visibleItems.isEmpty) {
        return widget.noResultsBuilder?.call(context, _debouncer.committedQuery) ??
            const NeutralNoResultsIndicator();
      }

      final visibleItems = result.visibleItems;
      final separatorBuilder = widget.separatorBuilder;
      final scroll = widget.scroll;
      final cacheExtentPixels = scroll.cacheExtent;
      final scrollCacheExtent = cacheExtentPixels == null
          ? null
          : ScrollCacheExtent.pixels(cacheExtentPixels);

      final effectiveItemBuilder = widget.grouping.decorate(
        widget.itemBuilder,
        flatItems: () => visibleItems,
        axis: scroll.scrollDirection,
      );

      return separatorBuilder != null
          ? ListView.separated(
              scrollDirection: scroll.scrollDirection,
              reverse: scroll.reverse,
              controller: scroll.controller,
              physics: scroll.physics,
              padding: scroll.padding,
              scrollCacheExtent: scrollCacheExtent,
              itemCount: visibleItems.length,
              itemBuilder: (context, index) =>
                  effectiveItemBuilder(context, visibleItems[index], index),
              separatorBuilder: separatorBuilder,
            )
          : ListView.builder(
              scrollDirection: scroll.scrollDirection,
              reverse: scroll.reverse,
              controller: scroll.controller,
              physics: scroll.physics,
              padding: scroll.padding,
              scrollCacheExtent: scrollCacheExtent,
              itemCount: visibleItems.length,
              itemBuilder: (context, index) =>
                  effectiveItemBuilder(context, visibleItems[index], index),
            );
    },
  );
}
