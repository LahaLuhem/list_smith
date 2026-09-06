part of '../search.dart';

/// No async search: the list is a plain paginated feed, with no search mode.
///
/// The default for [ListSmith.async]. Pass an [AsyncSearch] instead to turn search on. Extends
/// `Search<Never>`, so one `const NoSearch()` serves as the default for any `Search<T>`.
final class NoSearch extends Search<Never> {
  /// Creates the no-search default.
  const new();

  @override
  String toString() => 'NoSearch()';
}
