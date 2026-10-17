part of '../item_order.dart';

/// The list doesn't know the server's order. The default.
final class const UnknownOrder<T extends Object>() extends ItemOrder<T> {
  /// Creates it.
  this : super._();

  @override
  @internal
  Comparator<T>? get comparator => null;

  @override
  String toString() => 'UnknownOrder()';
}
