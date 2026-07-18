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
  String toString() => 'NoGrouping()';
}
