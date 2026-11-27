library;

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:pool/pool.dart';

import '/src/utils/tripwire.dart';
import '../enums/reload_on_error.dart';
import 'reload_context.dart';

part 'reloads/reload_to_current_depth.dart';
part 'reloads/reset_to_first_page.dart';

/// What pull-to-refresh does to the pages already loaded, which stay up until the fresh ones land.
///
/// [ResetToFirstPage] (the default) reads page 1 again and keeps just that. [ReloadToCurrentDepth]
/// re-reads every loaded page, so scroll depth survives.
sealed class const Reload() {
  /// Const base constructor.
  this;

  /// Does the reload through [context]. The engine calls it, you don't, same as `Widget.build`.
  @internal
  Future<void> run<T extends Object>(ReloadContext<T> context);
}

/// Re-reads the 1st [depth] pages and commits them only once every one landed, so a failure leaves
/// the list as it was.
Future<void> _rereadPages<T extends Object>(
  ReloadContext<T> context, {
  required int depth,
  int? concurrency = 1,
}) async {
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

  final failTripwire = Tripwire();
  Future<(List<T>, Object?)?> fetchOrNull(int index) async {
    if (failTripwire.hasTripped || context.isStale) return null; // its read would go to waste

    try {
      return await context.fetch(index, null);
    } on Exception {
      failTripwire.trip(); // the observer already saw the error

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
  if (failTripwire.hasTripped || context.isStale) return; // nothing whole to commit

  final pageReads = freshReads.nonNulls.toList(growable: false);
  await context.commit(
    pageReads.map((read) => read.$1).toList(growable: false),
    lastSignal: pageReads.last.$2, // a hasMore flag can end the list
  );
}
