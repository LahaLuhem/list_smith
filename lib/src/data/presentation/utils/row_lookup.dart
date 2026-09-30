import 'package:collection/collection.dart';

/// Where each row's item sits in one build of the async list, for its `findChildIndexCallback`.
///
/// A row is looked for at the index it was last built at, so rows that didn't move cost a check each.
/// The 1st row that did move builds an id-to-index map, and the rest of the build reuses it.
final class RowLookup<T extends Object> {
  final List<List<T>> _pages;
  final Object Function(T item) _itemId;

  /// Where each page starts in the flat list, then the total, so reading by index needs no flatten.
  late final List<int> _pageStarts = _startsOfPages();

  late final Map<Object, int> _indexById = _mapIds();

  /// Creates it over one build's [pages].
  new(List<List<T>> pages, Object Function(T item) itemId) : _pages = pages, _itemId = itemId;

  /// The item at flat [index].
  T itemAt(int index) {
    final page = lowerBound(_pageStarts, index + 1) - 1; // the last page starting at or before it

    return _pages[page][index - _pageStarts[page]];
  }

  /// Where the item with [id] sits now, or null once it's gone. [lastIndex] is where its row was last
  /// built.
  int? indexOf(Object id, int lastIndex) =>
      lastIndex < _pageStarts.last && _itemId(itemAt(lastIndex)) == id ? lastIndex : _indexById[id];

  List<int> _startsOfPages() =>
      _pages.fold([0], (starts, page) => starts..add(starts.last + page.length));

  Map<Object, int> _mapIds() {
    final indexById = <Object, int>{};
    var index = 0;
    // A loop, like the other per-item scans on the build path (APPENDIX.md#scan-loops).
    for (final page in _pages) {
      for (final item in page) {
        indexById[_itemId(item)] = index++;
      }
    }

    return indexById;
  }
}
