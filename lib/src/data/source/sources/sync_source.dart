part of '../list_source.dart';

/// A sync, in-memory source: the [items] to search over and the [searchBy] predicate that filters them.
///
/// A sync list is always about search (there is nothing to paginate or pull-to-refresh over an
/// in-memory list), so [searchBy] is required and never inert. [items] is kept as the raw iterable
/// the consumer passed and materialised once at the render boundary, following the house "accept a
/// general iterable, materialise deliberately" idiom; keeping the original reference lets the widget
/// tell an unchanged list from a new one and skip re-filtering.
final class SyncSource<T extends Object> extends ListSource<T> {
  /// The items to search over, as passed by the consumer (materialised once downstream).
  final Iterable<T> items;

  /// Decides whether an item matches the current query.
  final SyncSearchPredicate<T> searchBy;

  /// Bundles the in-memory search configuration built from the `.sync` constructor.
  const SyncSource({required this.items, required this.searchBy});

  @override
  String toString() => 'SyncSource()';
}
