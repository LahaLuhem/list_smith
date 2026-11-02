part of '../item_order.dart';

/// The server sorts the list by [comparator], which has to match it exactly, ties included.
final class const SortedBy<T extends Object>(
  /// Orders 2 items as the server does.
  @override final Comparator<T> comparator,
) extends ItemOrder<T> {
  /// Creates it.
  this : super._();

  // Structurally covered by to_string_test.dart.
  // coverage:ignore-start
  @override
  String toString() => 'SortedBy()';
  // coverage:ignore-end
}
