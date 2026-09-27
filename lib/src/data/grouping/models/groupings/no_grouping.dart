part of '../grouping.dart';

/// No grouping: a flat list, no section headers. The default.
final class NoGrouping<T extends Object> extends Grouping<T> {
  /// Creates it.
  const new();

  @override
  List<T> arrange(Iterable<T> items) => items is List<T> ? items : items.toList(growable: false);

  @override
  ItemBuilder<T> decorate(
    ItemBuilder<T> itemBuilder, {
    required Iterable<T> Function() flatItems,
    required Axis axis,
  }) => itemBuilder;

  @override
  int placementOf(T item, {required List<T> Function() flatItems}) => 0;

  @override
  bool isSameGroup(T a, T b) => true;

  @override
  String toString() => 'NoGrouping()';
}
