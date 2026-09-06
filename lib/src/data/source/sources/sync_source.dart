part of '../list_source.dart';

/// A sync, in-memory source: the [items] to search over and the [searchBy] that filters them.
///
/// Nothing to paginate or pull over an in-memory list, so [searchBy] is required and never inert.
/// [items] stays the raw iterable the consumer passed, materialised once downstream, so the widget
/// can tell an unchanged list from a new one and skip re-filtering.
final class SyncSource<T extends Object> extends ListSource<T> {
  /// The items to search over, as passed by the consumer (materialised once downstream).
  final Iterable<T> items;

  /// Decides whether an item matches the current query.
  final SyncSearchPredicate<T> searchBy;

  /// Bundles the in-memory search configuration built from the `.sync` constructor.
  const new({required this.items, required this.searchBy});

  @override
  String toString() => 'SyncSource()';
}
