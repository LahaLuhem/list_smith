part of '../reload.dart';

/// Throws away every loaded page and reloads just the 1st. The default: a pull puts the list back at
/// the top with fresh data.
///
/// A page still loading when the pull happens is dropped, so it can't land on the fresh list.
final class ResetToFirstPage extends Reload {
  /// Creates it.
  const new();

  @override
  Future<void> run<T extends Object>(ReloadContext<T> context) => Future.syncValue(context.reset());

  @override
  String toString() => 'ResetToFirstPage()';
}
