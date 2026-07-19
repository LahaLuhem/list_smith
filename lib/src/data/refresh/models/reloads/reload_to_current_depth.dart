part of '../reload.dart';

/// Re-fetches every currently-loaded page so a pull-to-refresh keeps the user's scroll depth instead
/// of snapping back to the first page.
///
/// [concurrency] bounds how many page-fetches run at once: `1` (the default) reloads one page at a
/// time, `null` reloads them all together, `K` keeps at most `K` in flight (a pool that refills as
/// slots free). [onError] decides how a failed page-fetch settles; see [ReloadOnError].
///
/// Both knobs are live only for index-based sources (a plain `PageFetcher`, where page `k` is fetchable
/// from `k` alone). A `PageFetcher.withSignal` source threads a per-page signal, so its reload runs
/// sequentially and atomically regardless of these settings: a broken cursor chain can't be partially
/// committed. It still keeps scroll depth, just without the tuning.
final class ReloadToCurrentDepth extends Reload {
  /// The most page-fetches to run at once: `1` (the default) sequential, `null` all together, `K` at
  /// most `K` in flight. Ignored for `withSignal` sources, which always reload sequentially.
  final int? concurrency;

  /// How the reload settles when a page-fetch fails; best-effort ([ReloadOnError.commitSucceeded]) by
  /// default. Ignored for `withSignal` sources, which are always atomic.
  final ReloadOnError onError;

  /// Creates a reload-to-current-depth strategy.
  const ReloadToCurrentDepth({this.concurrency = 1, this.onError = .commitSucceeded})
    : assert(concurrency == null || concurrency > 0, 'concurrency must be positive or null.');

  @override
  Future<void> run<T extends Object>(ReloadContext<T> context) {
    final old = context.loadedPages;
    if (old.isEmpty) return Future.sync(context.reset);

    return context.isSignalBased
        ? _reloadSequential(context, old.length)
        : _reloadParallel(context, old);
  }

  /// Signal-threaded, atomic reload for a `withSignal` source: walk the pages in order, and on any
  /// failure keep the old pages untouched (a partial cursor chain would be inconsistent).
  Future<void> _reloadSequential<T extends Object>(ReloadContext<T> context, int depth) async {
    final fresh = <List<T>>[];
    Object? signal;

    try {
      for (var index = 0; index < depth; index++) {
        final (items, pageSignal) = await context.fetch(index, signal);
        fresh.add(items);
        signal = pageSignal;
      }
    } on Exception {
      return; // keep the old pages; the observer already saw the error
    }

    context.commit(fresh, lastSignal: signal);
  }

  /// Concurrency-bounded reload for an index-based source, settled per [onError].
  Future<void> _reloadParallel<T extends Object>(
    ReloadContext<T> context,
    List<List<T>> old,
  ) async {
    final depth = old.length;
    final fresh = List<List<T>?>.filled(depth, null);
    final atomic = onError == .allOrNothing;
    var failed = false;

    Future<void> fetchInto(int index) async {
      if (atomic && failed) return; // fail-fast: skip once a page has failed

      try {
        final (items, _) = await context.fetch(index, null);
        fresh[index] = items;
      } on Exception {
        failed = true; // the observer already saw the error
      }
    }

    final limit = concurrency;
    if (limit == null) {
      await List.generate(depth, fetchInto).wait;
    } else {
      final pool = Pool(limit);
      await List.generate(depth, (index) => pool.withResource(() => fetchInto(index))).wait;
      await pool.close();
    }

    if (atomic && failed) return; // keep the old pages untouched

    context.commit([for (var index = 0; index < depth; index++) fresh[index] ?? old[index]]);
  }

  @override
  String toString() => 'ReloadToCurrentDepth(concurrency: $concurrency, onError: $onError)';
}
