part of '../grouping.dart';

/// The absence of grouping: the list renders as a flat sequence with no section headers.
///
/// The default [Grouping] for every list_smith list. It extends `Grouping<Never>` so the single
/// `const NoGrouping()` is assignable to a `Grouping<T>` parameter of any item type (`Never` is a
/// subtype of every type), which is what lets it be a `const` default without naming that type.
final class NoGrouping extends Grouping<Never> {
  /// Creates the no-grouping default.
  const NoGrouping();

  @override
  String toString() => 'NoGrouping()';
}
