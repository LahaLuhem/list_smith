part of '../search.dart';

/// No async search: the list is a plain paginated feed, with no search mode.
///
/// The default for [ListSmith.async]; opt into search by passing an [AsyncSearch] instead. Extends
/// `Search<Never>` (it carries no items), so one `const NoSearch()` is a valid default for any
/// `Search<T>`.
final class NoSearch extends Search<Never> {
  /// Creates the no-search default.
  const NoSearch();

  @override
  String toString() => 'NoSearch()';
}
