import 'package:flutter/widgets.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '/src/data/pagination/typedefs/item_id_getter.dart';
import '/src/data/pagination/typedefs/page_key.dart';
import '/src/data/presentation/utils/row_lookup.dart';

/// ISP's `PagedListView`, except a row follows its item: when rows above it come or go, it keeps its
/// state and anything it's animating.
///
/// Ours only because ISP's list can't take a `findChildIndexCallback`. It can go once ISP's does, or
/// animates its own inserts and removals:
/// https://github.com/EdsonBueno/infinite_scroll_pagination/issues/403,
/// https://github.com/EdsonBueno/infinite_scroll_pagination/issues/21.
class const KeyedPagedListView<T extends Object>({
  /// What renders, edits and de-dup already applied.
  required final PagingState<PageKey, T> state,

  /// Requests the next page.
  required final VoidCallback fetchNextPage,

  /// The item builder and ISP's surface slots.
  required final PagedChildBuilderDelegate<T> builderDelegate,

  /// Keys each row, so the list finds it again after a shift.
  required final ItemIdGetter<T> itemIdGetter,

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
    final rowLookup = RowLookup<T>(state.pages ?? const [], itemIdGetter);
    // One shape whatever the footer shows: the end, a new page loading, or its error.
    Widget listing(
      BuildContext _,
      IndexedWidgetBuilder itemBuilder,
      int itemCount,
      WidgetBuilder? footerBuilder,
    ) => _KeyedRows(
      rowLookup: rowLookup,
      itemIdGetter: itemIdGetter,
      itemBuilder: itemBuilder,
      itemCount: itemCount,
      footerBuilder: footerBuilder,
      separatorBuilder: separatorBuilder,
    );

    return PagedLayoutBuilder<PageKey, T>(
      layoutProtocol: .sliver,
      state: state,
      fetchNextPage: fetchNextPage,
      builderDelegate: builderDelegate,
      completedListingBuilder: listing,
      loadingListingBuilder: listing,
      errorListingBuilder: listing,
    );
  }
}

/// The sliver: the rows, keyed, then the footer as one more cell, so separators fall before it too,
/// as they do in ISP's list.
class const _KeyedRows<T extends Object>({
  required final RowLookup<T> rowLookup,
  required final ItemIdGetter<T> itemIdGetter,
  required final IndexedWidgetBuilder itemBuilder,
  required final int itemCount,
  required final WidgetBuilder? footerBuilder,
  required final IndexedWidgetBuilder? separatorBuilder,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cellCount = itemCount + (footerBuilder == null ? 0 : 1);
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

  Widget? _buildCell(BuildContext context, int index) => index < itemCount
      ? KeyedSubtree(
          key: _RowKey(itemIdGetter(rowLookup.itemAt(index)), index),
          child: itemBuilder(context, index),
        )
      : footerBuilder?.call(context);

  int? _indexOf(Key key) => key is _RowKey ? rowLookup.indexOf(key.id, key.index) : null;
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
