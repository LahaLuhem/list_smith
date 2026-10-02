import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '/src/data/pagination/models/paging_state.dart';
import '/src/data/pagination/typedefs/item_id_getter.dart';
import '/src/data/presentation/typedefs/item_builder.dart';
import '/src/data/presentation/utils/row_lookup.dart';

/// What the list shows instead of its rows, or after them, defaults already filled in.
typedef PagedSurfaces = ({
  WidgetBuilder firstPageLoading,
  WidgetBuilder firstPageError,
  WidgetBuilder noItemsFound,
  WidgetBuilder newPageLoading,
  WidgetBuilder newPageError,
  WidgetBuilder noMoreItems,
});

/// The async list: [state]'s rows, or the surface its status calls for. A row follows its item, so
/// when rows above it come or go, it keeps its state and anything it's animating.
class const KeyedPagedListView<T extends Object>({
  /// What renders, edits and de-dup already applied.
  required final PagingState<T> state,

  /// Builds each row.
  required final ItemBuilder<T> itemBuilder,

  /// Keys each row, so the list finds it again after a shift.
  required final ItemIdGetter<T> itemIdGetter,

  /// What shows instead of the rows, or after them.
  required final PagedSurfaces surfaces,

  /// Asks for the next page. Called while a row near the end builds.
  required final VoidCallback onNearEnd,

  /// Builds separators between items. Null for none.
  final IndexedWidgetBuilder? separatorBuilder,
  super.controller,
  super.scrollDirection,
  super.reverse,
  super.physics,
  super.padding,
  super.scrollCacheExtent,
  super.key,
}) extends BoxScrollView {
  /// Creates it.
  this;

  @override
  Widget buildChildLayout(BuildContext context) {
    final status = state.status;
    final firstPageBuilder = switch (status) {
      .loadingFirstPage => surfaces.firstPageLoading,
      .firstPageError => surfaces.firstPageError,
      .noItemsFound => surfaces.noItemsFound,
      .ongoing || .subsequentPageError || .completed => null,
    };

    return firstPageBuilder != null
        ? SliverFillRemaining(
            key: ValueKey(status), // so one surface replacing another starts fresh
            hasScrollBody: false,
            child: firstPageBuilder(context),
          )
        // One shape whatever the footer shows: the end, a new page loading, or its error.
        : _KeyedRows(
            rowLookup: RowLookup<T>(state.pages ?? const [], itemIdGetter),
            itemIdGetter: itemIdGetter,
            itemBuilder: itemBuilder,
            footerBuilder: switch (status) {
              .subsequentPageError => surfaces.newPageError,
              .completed => surfaces.noMoreItems,
              _ => surfaces.newPageLoading,
            },
            separatorBuilder: separatorBuilder,
            // Only here does scrolling ask for more, so a failed page waits for Retry.
            onNearEnd: status != .ongoing ? null : onNearEnd,
          );
  }
}

/// The sliver: the rows, keyed, then the footer as one more cell, so separators fall before it too.
class const _KeyedRows<T extends Object>({
  required final RowLookup<T> rowLookup,
  required final ItemIdGetter<T> itemIdGetter,
  required final ItemBuilder<T> itemBuilder,
  required final WidgetBuilder footerBuilder,
  required final IndexedWidgetBuilder? separatorBuilder,
  required final VoidCallback? onNearEnd,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cellCount = rowLookup.itemCount + 1;
    final separatorBuilder = this.separatorBuilder;

    return separatorBuilder == null
        ? SliverList.builder(
            itemCount: cellCount,
            itemBuilder: _buildCell,
            findChildIndexCallback: _indexOf,
          )
        : SliverList.separated(
            itemCount: cellCount,
            itemBuilder: _buildCell,
            separatorBuilder: separatorBuilder,
            findItemIndexCallback: _indexOf,
          );
  }

  Widget _buildCell(BuildContext context, int index) {
    final itemCount = rowLookup.itemCount;
    if (index >= itemCount) return footerBuilder(context);

    if (index >= math.max(0, itemCount - 1 - _nearEndRows)) onNearEnd?.call();
    final item = rowLookup.itemAt(index);

    return KeyedSubtree(
      key: _RowKey(itemIdGetter(item), index),
      child: itemBuilder(context, item, index),
    );
  }

  int? _indexOf(Key key) => key is _RowKey ? rowLookup.indexOf(key.id, key.index) : null;

  /// How many rows from the end a row's build asks for the next page.
  static const _nearEndRows = 3;
}

/// A row's item id, plus where it was built as a lookup hint. Equal on the id alone, so a row that
/// moved is still the same row.
final class const _RowKey(final Object id, final int index) extends LocalKey {
  @override
  bool operator ==(Object other) => other is _RowKey && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => '_RowKey(id: $id, index: $index)';
}
