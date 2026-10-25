import 'package:meta/meta.dart';

import '/src/data/pagination/pagination.dart';

/// Where each row's item sits in one build of the list, for its `findChildIndexCallback`.
///
/// A row is looked for near where it was last built, since rows shift by however many landed or left
/// above. Only a row that's gone or moved far builds the id map.
@internal
final class RowLookup<T extends Object>(
  final List<List<T>> _pages,
  final ItemIdGetter<T> _itemIdGetter,
) {
  /// Where each page starts in the flat list, then the total, so reading by index needs no flatten.
  late final List<int> _pageStarts = _pages.fold([
    0,
  ], (starts, items) => starts..add(starts.last + items.length));

  /// Each item's index by id, once a lookup has needed it.
  Map<Object, int>? _indexById;

  /// Creates it over one build's items, page by page.
  this;

  /// How many items the pages hold.
  int get itemCount => _pageStarts.last;

  /// The item at flat [index].
  T itemAt(int index) {
    // A typed search, `lowerBound` measured several times slower (APPENDIX.md#scan-loops).
    var pageIndex = 0;
    var upperPageIndex = _pageStarts.length - 2;
    while (pageIndex < upperPageIndex) {
      final middlePageIndex = (pageIndex + upperPageIndex + 1) >> 1;
      if (_pageStarts[middlePageIndex] <= index) {
        pageIndex = middlePageIndex;
      } else {
        upperPageIndex = middlePageIndex - 1;
      }
    }

    return _pages[pageIndex][index - _pageStarts[pageIndex]];
  }

  /// Where the item with [id] sits now, or null once it's gone. [lastIndex] is where its row was last
  /// built.
  int? indexOf(Object id, int lastIndex) {
    final builtIndexById = _indexById;
    if (builtIndexById != null) return builtIndexById[id];

    if (_isAt(id, lastIndex)) return lastIndex;
    for (var distance = 1; distance <= _nearbyRows; distance++) {
      if (_isAt(id, lastIndex + distance)) return lastIndex + distance;
      if (_isAt(id, lastIndex - distance)) return lastIndex - distance;
    }

    final indexById = <Object, int>{};
    var index = 0;
    // A loop, like the other per-item scans on the build path (APPENDIX.md#scan-loops).
    for (final items in _pages) {
      for (final item in items) {
        indexById[_itemIdGetter(item)] = index++;
      }
    }
    _indexById = indexById;

    return indexById[id];
  }

  bool _isAt(Object id, int index) =>
      index >= 0 && index < itemCount && _itemIdGetter(itemAt(index)) == id;

  /// Enough to cover a page landing above.
  static const _nearbyRows = 32;
}
