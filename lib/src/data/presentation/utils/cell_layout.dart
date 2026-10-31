import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../enums/cell_kind.dart';
import '../typedefs/group_header.dart';

/// A child of the rows sliver: what it shows, and its header's or its item's index.
@internal
typedef Cell = ({CellKind kind, int index});

/// What each child of the rows sliver shows: a row, a header, a separator or the footer.
///
/// Headers are few, so the rest is index math around them.
@internal
final class const CellLayout({
  /// How many items the rows show.
  required final int itemCount,

  /// Whether separators sit between items, and before the footer.
  required final bool hasSeparators,

  /// Whether a footer follows the rows.
  required final bool hasFooter,

  /// The group headers, in list order.
  required final List<GroupHeader> headers,

  /// Whether a header sits after its group's last item, as on a reversed list, rather than before its
  /// 1st.
  required final bool isHeaderAfterItem,
}) {
  /// Creates it.
  this;

  /// How many children the sliver has.
  int get childCount =>
      (hasFooter
          ? itemCount * _childrenPerItem + 1
          : math.max(0, itemCount * _childrenPerItem - (_childrenPerItem - 1))) +
      headers.length;

  /// What the child at [childIndex] shows.
  Cell cellAt(int childIndex) {
    final headersUpTo = _countHeaders(
      (headerIndex) => childIndexOfHeader(headerIndex) <= childIndex,
    );
    if (headersUpTo > 0 && childIndexOfHeader(headersUpTo - 1) == childIndex) {
      return (kind: .header, index: headersUpTo - 1);
    }

    final indexWithoutHeaders = childIndex - headersUpTo;
    if (hasFooter && indexWithoutHeaders == itemCount * _childrenPerItem) {
      return (kind: .footer, index: itemCount);
    }

    return (
      kind: hasSeparators && indexWithoutHeaders.isOdd ? .separator : .item,
      index: indexWithoutHeaders ~/ _childrenPerItem,
    );
  }

  /// The child showing the item at [itemIndex].
  int childIndexOfItem(int itemIndex) =>
      itemIndex * _childrenPerItem +
      _countHeaders((headerIndex) {
        final headerItemIndex = itemIndexOfHeader(headerIndex);

        return headerItemIndex < itemIndex || (headerItemIndex == itemIndex && !isHeaderAfterItem);
      });

  /// The child showing the header at [headerIndex].
  int childIndexOfHeader(int headerIndex) =>
      itemIndexOfHeader(headerIndex) * _childrenPerItem + (isHeaderAfterItem ? 1 : 0) + headerIndex;

  /// The item the header at [headerIndex] sits by: its group's 1st, or its last when headers sit after.
  int itemIndexOfHeader(int headerIndex) {
    if (!isHeaderAfterItem) return headers[headerIndex].itemIndex;

    final nextHeaderIndex = headerIndex + 1;
    final nextGroupStartIndex = nextHeaderIndex < headers.length
        ? headers[nextHeaderIndex].itemIndex
        : itemCount;

    return nextGroupStartIndex - 1;
  }

  int get _childrenPerItem => hasSeparators ? 2 : 1;

  /// How many headers [isBefore] holds for, from the 1st. Typed, not `lowerBound`
  /// (APPENDIX.md#scan-loops).
  int _countHeaders(bool Function(int headerIndex) isBefore) {
    var count = 0;
    var upperCount = headers.length;
    while (count < upperCount) {
      final middleIndex = (count + upperCount) >> 1;
      if (isBefore(middleIndex)) {
        count = middleIndex + 1;
      } else {
        upperCount = middleIndex;
      }
    }

    return count;
  }
}
