part of '../grouping.dart';

/// No grouping: a flat list, no section headers. The default.
final class const NoGrouping<T extends Object>() extends Grouping<T> {
  /// Creates it.
  this;

  @override
  @internal
  List<T> arrange(Iterable<T> items) => items is List<T> ? items : items.toList(growable: false);

  @override
  @internal
  ItemBuilder<T> decorate(
    ItemBuilder<T> itemBuilder, {
    required Iterable<T> Function() flattenItems,
    required Axis axis,
  }) => itemBuilder;

  @override
  @internal
  GroupKeyOf<T, Object>? get groupOf => null;

  @override
  String toString() => 'NoGrouping()';
}
