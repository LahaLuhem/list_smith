part of '../list_source.dart';

/// A sync, in-memory source: the [items] to search over and the [searchBy] that filters them.
///
/// Nothing to paginate or pull over in-memory data, so [searchBy] is required. [items] stays the raw
/// iterable you passed, turned into a list once downstream, so the widget can tell an unchanged list
/// from a new one and skip re-filtering.
final class const SyncSource<T extends Object>({
  /// The items to search over, exactly as you passed them.
  required final Iterable<T> items,

  /// Decides whether an item matches the current query.
  required final SyncSearchPredicate<T> searchBy,
}) extends ListSource<T> {
  /// Creates it.
  this;

  @override
  String toString() => 'SyncSource()';
}
