import 'package:meta/meta.dart';

import '/src/data/pagination/pagination.dart';

/// The 1st item of each id in [items], in order, and the 1st id to come back, null if none did.
@internal
({List<T> items, Object? repeatedId}) firstOfEachId<T extends Object>(
  Iterable<T> items,
  ItemIdGetter<T> itemIdGetter,
) {
  final seenIds = <Object>{};
  final keptItems = <T>[];
  Object? repeatedId;
  // A loop, like the other per-item scans on the build path (APPENDIX.md#scan-loops).
  for (final item in items) {
    final id = itemIdGetter(item);
    if (seenIds.add(id)) {
      keptItems.add(item);
    } else {
      repeatedId ??= id;
    }
  }

  return (items: keptItems, repeatedId: repeatedId);
}
