part of '../reload.dart';

/// Re-fetches every currently-loaded page so a pull-to-refresh keeps the user's scroll depth instead
/// of snapping back to the first page.
///
/// [concurrency] and [onError] are live only for index-based sources. A `PageFetcher.withSignal`
/// source threads a per-page signal, so page `k` needs page `k-1`: its reload walks in order and is
/// always atomic, since a half-rewritten cursor chain can't be committed. Scroll depth is still
/// kept, just without the tuning.
///
/// A page still loading when the pull happens is dropped and asked again, so pre-refresh data can't
/// land on top of the refreshed pages.
final class ReloadToCurrentDepth extends Reload {
  /// The most page-fetches to run at once: `1` (the default) sequential, `null` all together, `K` at
  /// most `K` in flight. Ignored for `withSignal` sources, which always reload sequentially.
  final int? concurrency;

  /// How the reload settles when a page-fetch fails. Best-effort
  /// ([ReloadOnError.commitSucceeded]) by default. Ignored for `withSignal` sources, always atomic.
  final ReloadOnError onError;

  /// Creates a reload-to-current-depth strategy.
  const new({this.concurrency = 1, this.onError = .commitSucceeded})
    : assert(concurrency == null || concurrency > 0, 'concurrency must be positive or null.');

  @override
  Future<void> run<T extends Object>(ReloadContext<T> context) {
    final old = context.loadedPages;
    if (old.isEmpty) return Future.sync(context.reset);

    return context.isSignalBased
        ? _reloadSequential(context, old.length)
        : _reloadParallel(context, old);
  }

  /// Atomic, in-order reload for a `withSignal` source. Any failure keeps the old pages untouched.
  Future<void> _reloadSequential<T extends Object>(ReloadContext<T> context, int depth) async {
    final fresh = <List<T>>[];
    Object? signal;

    try {
      for (var index = 0; index < depth; index++) {
        if (context.isStale) return;
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
      if (context.isStale) return;

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
