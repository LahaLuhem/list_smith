part of '../reload.dart';

/// Re-fetches every loaded page, so a pull keeps the user's scroll depth instead of snapping back to
/// the start.
///
/// If a page fails, the list stays as it was, since pages read at different times can lose or repeat
/// rows where they meet.
///
/// A page still loading when the pull happens is dropped and asked again, so stale data can't land on
/// top of the fresh pages.
final class const ReloadToCurrentDepth({
  /// How many page fetches may run at once: `1` (the default) sequential, `null` all together, `K` at
  /// most `K` in flight. A `withSignal` source ignores it, since page `k` needs page `k-1`.
  final int? concurrency = 1,

  /// Ignored.
  @Deprecated('Does nothing now. Remove it, it goes at the next major.')
  final ReloadOnError onError = .commitSucceeded,
}) extends Reload {
  /// Creates it.
  this : assert(concurrency == null || concurrency > 0, 'concurrency must be positive or null.');

  @override
  @internal
  Future<void> run<T extends Object>(ReloadContext<T> context) =>
      _rereadPages(context, depth: context.depth, concurrency: concurrency);

  @override
  String toString() =>
      'ReloadToCurrentDepth('
      'concurrency: $concurrency'
      ')';
}
