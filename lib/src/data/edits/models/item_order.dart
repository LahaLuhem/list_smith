/// @docImport '/src/widgets/list_smith.dart';
library;

import 'package:meta/meta.dart';

part 'item_orders/sorted_by.dart';
part 'item_orders/unknown_order.dart';

/// How the server sorts the list, so an edit can land where the server puts it.
///
/// [UnknownOrder] (the default) puts a new item on top and leaves an edited one in place. [SortedBy]
/// places both by the order. [ListSmith.async] only, like the edits.
sealed class const ItemOrder<T extends Object>._() {
  /// Orders 2 items, null when the order isn't known.
  @internal
  Comparator<T>? get comparator;
}
