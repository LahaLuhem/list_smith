part of '../reload.dart';

/// Discards every loaded page and reloads only the first, the underlying pager's own refresh and the
/// default. A pull returns the list to the top with fresh data.
final class ResetToFirstPage extends Reload {
  /// Creates the reset-to-first-page reload (the default).
  const ResetToFirstPage();

  @override
  Future<void> run<T extends Object>(ReloadContext<T> context) {
    context.reset();

    return Future<void>.value();
  }

  @override
  String toString() => 'ResetToFirstPage()';
}
