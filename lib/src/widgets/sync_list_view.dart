/// @docImport 'list_smith.dart';
library;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import '/src/data/grouping/grouping.dart';
import '/src/data/presentation/presentation.dart';
import '/src/data/search/search.dart';
import '/src/data/source/source.dart';
import '/src/utils/query_debouncer.dart';
import '/src/utils/report_bad_data.dart';
import 'defaults/defaults.dart';
import 'keyed_list_view.dart';

/// The sync engine behind [ListSmith.sync]: filters an in-memory [SyncSource] by the debounced query
/// and shows it in the same keyed list as `.async`.
///
/// No paging controller and no pull-to-refresh, since in-memory data has nothing to page or refresh.
@internal
class const SyncListView<T extends Object>({
  /// The items and the predicate that filters them.
  required final SyncSource<T> source,

  /// The current search query, yours to own and pass in.
  required final String query,

  /// Minimum trimmed query length before a search runs. Below it the query counts as empty.
  required final int minSearchLength,

  /// How long to wait after [query] changes before filtering. [Duration.zero] filters at once.
  required final Duration searchDebounce,

  /// Builds the widget for each item.
  required final ItemBuilder<T> itemBuilder,

  /// Splits the visible items into sections. [NoGrouping] (the default) renders a flat list.
  required final Grouping<T> grouping,

  /// Scroll and layout configuration for the underlying scrollable.
  required final ListScrollConfig scrollConfig,

  /// Builds the separator between items. Null for none.
  final IndexedWidgetBuilder? separatorBuilder,

  /// Builds the surface shown when the source has no items. Null uses the neutral default.
  final WidgetBuilder? emptyBuilder,

  /// Builds the surface shown when a search matches nothing. Null uses the neutral default.
  final NoResultsBuilder? noResultsBuilder,
  super.key,
}) extends StatefulWidget {
  /// Creates it.
  this;

  @override
  State<SyncListView<T>> createState() => _SyncListViewState<T>();
}

class _SyncListViewState<T extends Object>() extends State<SyncListView<T>> {
  late final _debouncer = QueryDebouncer(onCommitted: _onQueryCommitted);
  late final ValueNotifier<({List<T> visibleItems, bool isSearching})> _resultNotifier;
  late List<T> _items;

  /// The items as passed, kept in debug for the in-place check, since [_items] drops repeated ids.
  List<T>? _passedItems;
  var _didItemsChangeInPlace = false;

  @override
  void initState() {
    super.initState();

    _debouncer.seed(widget.query, minSearchLength: widget.minSearchLength);
    _takeItems();
    _resultNotifier = ValueNotifier(_resolve());
  }

  @override
  void didUpdateWidget(SyncListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    final didItemsChange = !identical(widget.source.items, oldWidget.source.items);
    if (didItemsChange) _takeItems();
    if (kDebugMode) {
      // Walk here, instead of on every rebuild in the build method.
      _didItemsChangeInPlace =
          !didItemsChange &&
          !const IterableEquality<Object>(IdentityEquality())
              .equals(_passedItems, widget.source.items);
    }
    if (didItemsChange || !identical(widget.grouping, oldWidget.grouping)) {
      _resultNotifier.value = _resolve();
    }

    if (widget.query != oldWidget.query) {
      _debouncer.schedule(
        widget.query,
        widget.searchDebounce,
        minSearchLength: widget.minSearchLength,
      );
    }
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _resultNotifier.dispose();

    super.dispose();
  }

  /// Copies the source's items, each id once, since keyed rows can't share one.
  void _takeItems() {
    final source = widget.source;
    final itemIdGetter = source.itemIdGetter;
    final (:items, :repeatedId) = itemIdGetter == null
        ? (items: source.items.toList(growable: false), repeatedId: null)
        : firstOfEachId(source.items, itemIdGetter);
    _items = items;
    if (kDebugMode) _passedItems = source.items.toList(growable: false);
    if (kDebugMode && repeatedId != null) {
      reportBadData(
        "ListSmith.sync's itemIdGetter gave $repeatedId for more than one item. Ids have to be "
        'unique, so only the 1st shows.',
      );
    }
  }

  ({List<T> visibleItems, bool isSearching}) _resolve() {
    final searchResult = resolveSyncSearch(
      _items,
      widget.source.searchBy,
      _debouncer.committedQuery,
    );

    return (
      visibleItems: widget.grouping.arrange(searchResult.visibleItems),
      isSearching: searchResult.isSearching,
    );
  }

  void _onQueryCommitted(String committedQuery) => _resultNotifier.value = _resolve();

  @override
  Widget build(BuildContext context) {
    // Here, not where the items land: a throw in didUpdateWidget leaves the element tree broken.
    assert(
      !_didItemsChangeInPlace,
      "ListSmith.sync's items came back as the same list, edited in place. It only reads a new "
      'list, so pass a copy with the change, like [...items, newItem].',
    );

    return ValueListenableBuilder(
      valueListenable: _resultNotifier,
      builder: (context, result, _) {
        final isEmpty = _items.isEmpty;
        final Widget? surfaceWidget;
        if (isEmpty) {
          surfaceWidget = widget.emptyBuilder?.call(context) ?? const NeutralEmptyIndicator();
        } else if (result.isSearching && result.visibleItems.isEmpty) {
          surfaceWidget =
              widget.noResultsBuilder?.call(context, _debouncer.committedQuery) ??
              const NeutralNoResultsIndicator();
        } else {
          surfaceWidget = null;
        }
        final scrollConfig = widget.scrollConfig;

        return KeyedListView(
          pagedItems: [result.visibleItems],
          itemBuilder: widget.itemBuilder,
          grouping: widget.grouping,
          pullExtentListenable: const AlwaysStoppedAnimation(0),
          shouldKeepPosition: widget.source.shouldKeepPosition,
          startKey: _debouncer.committedQuery,
          itemIdGetter: widget.source.itemIdGetter,
          // Keyed by which surface, so one replacing the other starts fresh.
          surface: surfaceWidget == null
              ? null
              : KeyedSubtree(key: ValueKey(isEmpty), child: surfaceWidget),
          separatorBuilder: widget.separatorBuilder,
          controller: scrollConfig.controller,
          scrollDirection: scrollConfig.scrollDirection,
          reverse: scrollConfig.reverse,
          physics: scrollConfig.physics,
          padding: scrollConfig.padding,
          scrollCacheExtent: scrollConfig.scrollCacheExtent,
        );
      },
    );
  }
}
