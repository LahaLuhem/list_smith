part of '../grouping.dart';

/// The absence of grouping: the list renders as a flat sequence with no section headers.
///
/// The default [Grouping] for every list_smith list, created as `NoGrouping<T>()` for the list's item
/// type when the consumer passes no [Grouping]. Generic in [T] (rather than a single shared
/// `Grouping<Never>` instance) so its per-item operations receive real `T`-typed values.
final class NoGrouping<T extends Object> extends Grouping<T> {
  /// Creates the no-grouping default.
  const NoGrouping();

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
