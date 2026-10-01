part of '../search.dart';

/// No async search: a plain paginated feed. The default. Pass an [AsyncSearch] to turn search on.
final class const NoSearch() extends Search<Never> {
  /// Creates it.
  this;

  @override
  String toString() => 'NoSearch()';
}
