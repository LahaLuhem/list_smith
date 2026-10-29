import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '/src/data/grouping/grouping.dart';
import '/src/data/pagination/pagination.dart';
import '/src/data/presentation/presentation.dart';
import 'scroll_anchor.dart';

/// A list of rows that follow their item, or a surface in their place. When rows above a row come or
/// go, it keeps its state and anything it's animating.
@internal
class const KeyedListView<T extends Object>({
  /// One list per page, in order.
  required final List<List<T>> pagedItems,

  /// Builds each row.
  required final ItemBuilder<T> itemBuilder,

  /// Splits the items into sections under headers, so the rows can come out of page order.
  required final Grouping<T> grouping,

  /// How far a pull pushes the list now.
  required final ValueListenable<double> pullExtentListenable,

  /// Whether the row on top holds still when rows above it change, or a pull's room does.
  required final bool shouldKeepPosition,

  /// Takes the list back to its start whenever it changes, as a new committed query does.
  required final Object startKey,

  /// Keys each row, so the list finds it again after a shift. Null leaves rows by position, while
  /// `.sync` takes lists without ids.
  final ItemIdGetter<T>? itemIdGetter,

  /// Builds the cell after the rows. Null for none.
  final WidgetBuilder? footerBuilder,

  /// Shows instead of the rows. Key it, so one replacing another starts fresh.
  final Widget? surface,

  /// Asks for the next page. Called while a row near the end builds.
  final VoidCallback? onNearEnd,

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
    final surface = this.surface;
    final Widget contentSliver;
    if (surface == null) {
      final (pagedItems: shownPagedItems, :groupHeaders) = grouping.sectionsOver(
        pagedItems,
        isReversed: reverse,
      );
      contentSliver = _KeyedRows(
        rowLookup: RowLookup<T>(shownPagedItems, itemIdGetter ?? _neverLookedUp),
        groupHeaders: groupHeaders,
        itemIdGetter: itemIdGetter,
        itemBuilder: itemBuilder,
        footerBuilder: footerBuilder,
        separatorBuilder: separatorBuilder,
        onNearEnd: onNearEnd,
        pullExtentListenable: pullExtentListenable,
        shouldKeepPosition: shouldKeepPosition,
      );
    } else {
      // As [BoxScrollView] pads: [padding], else the safe area.
      final resolvedInsets = (padding ?? MediaQuery.maybePaddingOf(context) ?? .zero).resolve(
        Directionality.maybeOf(context),
      );
      contentSliver = _SurfaceSlot(
        // So a short surface has nothing to scroll.
        trailingPaddingExtent: switch (getDirection(context)) {
          .down => resolvedInsets.bottom,
          .up => resolvedInsets.top,
          .right => resolvedInsets.right,
          .left => resolvedInsets.left,
        },
        child: surface,
      );
    }

    return _ScrollStart(startKey: startKey, sliver: contentSliver);
  }

  // Rows without ids aren't keyed or anchored, so nothing looks them up.
  static Object _neverLookedUp(Object _) =>
      throw StateError('Rows without ids are never looked up.');
}

/// Unlike `SliverFillRemaining`, never measures the surface or resizes it while scrolling.
class const _SurfaceSlot({required final double trailingPaddingExtent, required final Widget child})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (_, constraints) {
      final remainingExtent = math.max<double>(
        0,
        constraints.viewportMainAxisExtent -
            constraints.precedingScrollExtent -
            trailingPaddingExtent,
      );

      return SliverToBoxAdapter(
        child: constraints.axis == .vertical
            ? SizedBox(height: remainingExtent, child: child)
            : SizedBox(width: remainingExtent, child: child),
      );
    },
  );
}

/// Takes the list back to its start when [startKey] changes, in the same frame and with any scroll
/// controller or none.
class const _ScrollStart({required final Object startKey, required Widget sliver})
    extends SingleChildRenderObjectWidget {
  this : super(child: sliver);

  @override
  _RenderScrollStart createRenderObject(BuildContext context) => _RenderScrollStart(startKey);

  @override
  void updateRenderObject(BuildContext context, _RenderScrollStart renderObject) =>
      renderObject.startKey = startKey;
}

class _RenderScrollStart(Object startKey) extends RenderProxySliver {
  var _startKey = startKey;
  var _isGoingToStart = false;

  set startKey(Object value) {
    if (value == _startKey) return;

    _startKey = value;
    _isGoingToStart = true;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    if (_isGoingToStart) {
      _isGoingToStart = false;
      final pixels = (RenderAbstractViewport.of(this) as RenderViewportBase).offset.pixels;
      if (pixels > precisionErrorTolerance) {
        geometry = SliverGeometry(scrollOffsetCorrection: -pixels);

        return;
      }
    }

    super.performLayout();
  }
}

/// The sliver: keyed rows and headers, then the footer as one more cell, so separators fall before it
/// too.
class const _KeyedRows<T extends Object>({
  required final RowLookup<T> rowLookup,
  required final GroupHeaders? groupHeaders,
  required final ItemIdGetter<T>? itemIdGetter,
  required final ItemBuilder<T> itemBuilder,
  required final WidgetBuilder? footerBuilder,
  required final IndexedWidgetBuilder? separatorBuilder,
  required final VoidCallback? onNearEnd,
  required final ValueListenable<double> pullExtentListenable,
  required final bool shouldKeepPosition,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cellLayout = CellLayout(
      itemCount: rowLookup.itemCount,
      hasSeparators: separatorBuilder != null,
      hasFooter: footerBuilder != null,
      headers: groupHeaders?.headers ?? const [],
      isHeaderAfterItem: groupHeaders?.isAfterItem ?? false,
    );
    final rowsSliverList = SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, childIndex) => _buildCell(context, cellLayout.cellAt(childIndex)),
        childCount: cellLayout.childCount,
        findChildIndexCallback: (key) => _indexOf(key, cellLayout),
        // Screen readers count rows and the footer as list entries, not headers or separators.
        semanticIndexCallback: (_, childIndex) {
          final (:kind, :index) = cellLayout.cellAt(childIndex);

          return kind == .item || kind == .footer ? index : null;
        },
      ),
    );
    final itemIdGetter = this.itemIdGetter;
    if (!shouldKeepPosition || itemIdGetter == null) return rowsSliverList;

    return ScrollAnchor(
      rowIdGetter: (childIndex) {
        final (:kind, :index) = cellLayout.cellAt(childIndex);

        return kind == .item ? itemIdGetter(rowLookup.itemAt(index)) : null;
      },
      rowIndexGetter: (id, lastChildIndex) {
        final (:kind, :index) = cellLayout.cellAt(lastChildIndex);
        // Only a hint for the lookup, so a header stands in for the item it sits by.
        final itemIndex = rowLookup.indexOf(
          id,
          kind == .header ? groupHeaders!.headers[index].itemIndex : index,
        );

        return itemIndex == null ? null : cellLayout.childIndexOfItem(itemIndex);
      },
      pullExtentListenable: pullExtentListenable,
      sliver: rowsSliverList,
    );
  }

  Widget _buildCell(BuildContext context, Cell cell) {
    final (:kind, :index) = cell;
    // A header, separator or footer cell only exists when its builder does.
    switch (kind) {
      case .header:
        final groupHeaders = this.groupHeaders!;
        final groupKey = groupHeaders.headers[index].key;

        return KeyedSubtree(
          key: _HeaderKey(groupKey, index),
          child: groupHeaders.headerFor(context, groupKey),
        );
      case .separator:
        return separatorBuilder!(context, index);
      case .footer:
        return footerBuilder!(context);
      case .item:
        final itemCount = rowLookup.itemCount;
        if (index >= math.max(0, itemCount - 1 - _nearEndRows)) onNearEnd?.call();
        final item = rowLookup.itemAt(index);
        final itemIdGetter = this.itemIdGetter;
        final rowWidget = itemBuilder(context, item, index);

        return itemIdGetter == null
            ? rowWidget
            : KeyedSubtree(key: _RowKey(itemIdGetter(item), index), child: rowWidget);
    }
  }

  int? _indexOf(Key key, CellLayout cellLayout) {
    if (key is _RowKey) {
      final itemIndex = rowLookup.indexOf(key.id, key.index);

      return itemIndex == null ? null : cellLayout.childIndexOfItem(itemIndex);
    }
    if (key is _HeaderKey) {
      final headerIndex = groupHeaders?.indexOf(key.groupKey, key.index);

      return headerIndex == null ? null : cellLayout.childIndexOfHeader(headerIndex);
    }

    return null;
  }

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

/// A header's group key, plus where it was built as a lookup hint. Equal on the key alone, so a
/// header that moved is still the same header.
final class const _HeaderKey(final Object groupKey, final int index) extends LocalKey {
  @override
  bool operator ==(Object other) => other is _HeaderKey && other.groupKey == groupKey;

  @override
  int get hashCode => groupKey.hashCode;

  @override
  String toString() => '_HeaderKey(groupKey: $groupKey, index: $index)';
}
