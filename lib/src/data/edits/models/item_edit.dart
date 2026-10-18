import 'package:meta/meta.dart';

/// A local change to one item. A class, not a record (APPENDIX.md#edit-store-scans).
@immutable
@internal
final class const ItemEdit<T extends Object>({
  /// Its new value, or null once removed.
  required final T? item,

  /// The edit counter when it was made.
  required final int stamp,
}) {
  /// Creates it.
  this;

  @override
  String toString() => 'ItemEdit(item: $item, stamp: $stamp)';
}
