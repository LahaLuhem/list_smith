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
  ({List<List<T>> pagedItems, GroupHeaders? groupHeaders}) sectionsOver(
    List<List<T>> pagedItems, {
    required bool isReversed,
  }) => (pagedItems: pagedItems, groupHeaders: null);

  @override
  @internal
  GroupKeyOf<T, Object>? get groupOf => null;

  @override
  String toString() => 'NoGrouping()';
}
