part of '../search.dart';

/// No async search: a plain paginated feed. The default. Pass an [AsyncSearch] to turn search on.
final class NoSearch extends Search<Never> {
  /// Creates it.
  const new();

  @override
  String toString() => 'NoSearch()';
}
