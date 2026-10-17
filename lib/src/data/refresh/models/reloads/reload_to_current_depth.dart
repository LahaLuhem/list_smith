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
  Future<void> run<T extends Object>(ReloadContext<T> context) async {
    final depth = context.depth;
    if (depth == 0) {
      await context.reset();

      return;
    }

    // Page k needs page k-1's signal, so one page at a time.
    if (context.isSignalBased) {
      final freshPages = <List<T>>[];
      Object? signal;
      try {
        for (var index = 0; index < depth; index++) {
          if (context.isStale) return;
          final (items, pageSignal) = await context.fetch(index, signal);
          freshPages.add(items);
          signal = pageSignal;
        }
      } on Exception {
        return; // keep the old pages, the observer already saw the error
      }

      await context.commit(freshPages, lastSignal: signal);

      return;
    }

    var didFail = false;
    Future<(List<T>, Object?)?> fetchOrNull(int index) async {
      if (didFail || context.isStale) return null; // its read would go to waste

      try {
        return await context.fetch(index, null);
      } on Exception {
        didFail = true; // the observer already saw the error

        return null;
      }
    }

    // A pool as wide as the depth is "all at once", so a null concurrency needs no branch of its own.
    final pool = Pool(concurrency ?? depth);
    final freshReads = await Iterable.generate(
      depth,
      (index) => pool.withResource(() => fetchOrNull(index)),
    ).wait;
    await pool.close();
    if (didFail || context.isStale) return; // nothing whole to commit

    final pageReads = freshReads.nonNulls.toList(growable: false);
    await context.commit(
      pageReads.map((read) => read.$1).toList(growable: false),
      lastSignal: pageReads.last.$2, // a hasMore flag can end the list
    );
  }

  @override
  String toString() => 'ReloadToCurrentDepth(concurrency: $concurrency)';
}
