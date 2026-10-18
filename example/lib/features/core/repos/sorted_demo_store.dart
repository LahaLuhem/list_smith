import 'package:collection/collection.dart';

import '../data/models/demo_item.dart';
import 'demo_repository.dart';

/// A writable copy of [DemoRepository]'s read-only items, kept in a server's order.
final class SortedDemoStore(final Comparator<DemoItem> _comparator) {
  late final _storedItems = DemoRepository().items.sorted(_comparator);

  /// Below every existing id, so it's never taken.
  var _nextNewId = -1;

  Iterable<DemoItem> get items => _storedItems;

  int takeNewId() => _nextNewId--;

  /// At its sorted spot, in place of the item with its id.
  void put(DemoItem item) => _storedItems
    ..removeWhere((storedItem) => storedItem.id == item.id)
    ..insert(lowerBound(_storedItems, item, compare: _comparator), item);

  void remove(int id) => _storedItems.removeWhere((storedItem) => storedItem.id == id);
}
