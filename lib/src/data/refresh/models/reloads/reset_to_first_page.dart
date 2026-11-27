part of '../reload.dart';

/// Reads page 1 again and shows it in place of every loaded page once it lands. The default: a pull
/// puts the list back at the start with fresh data.
///
/// A page still loading when the pull happens is dropped, so it can't land on the fresh list.
final class const ResetToFirstPage() extends Reload {
  /// Creates it.
  this;

  @override
  @internal
  Future<void> run<T extends Object>(ReloadContext<T> context) => _rereadPages(context, depth: 1);

  // Structurally covered by to_string_test.dart.
  // coverage:ignore-start
  @override
  String toString() => 'ResetToFirstPage()';
  // coverage:ignore-end
}
