part of '../grouping.dart';

/// The absence of grouping: the list renders as a flat sequence with no section headers.
///
/// The default, built as `NoGrouping<T>()` at the list's own item type. Generic in [T] rather than
/// one shared `Grouping<Never>`, so its per-item operations get real `T` values.
final class NoGrouping<T extends Object> extends Grouping<T> {
  /// Creates the no-grouping default.
  const new();

  @override
  List<T> arrange(Iterable<T> items) => items is List<T> ? items : items.toList(growable: false);

  @override
  ItemBuilder<T> decorate(
    ItemBuilder<T> itemBuilder, {
    required List<T> Function() flatItems,
    required Axis axis,
  }) => itemBuilder;

  @override
  String toString() => 'NoGrouping()';
}
