import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import 'list_smith_harness.dart';

/// A store behind the fetchers, with holds and failures keyed by page and attempt.
final class FakeServer<T extends Object> {
  final List<T> store;
  final requests = <PageRequest>[];
  final attempts = <int, int>{};
  final failing = <(int, int)>{};
  final _holds = <(int, int), Completer<void>>{};

  new(Iterable<T> items) : store = [...items];

  Completer<void> hold(int page, {required int attempt}) =>
      _holds[(page, attempt)] = Completer<void>();

  bool asked(int page) => attempts.containsKey(page);

  /// Offset paging, reading the store once the request reaches it.
  PageFetcher<T> get offsetLate => PageFetcher((request) async {
    await _arrive(request);

    return _window(request);
  });

  /// Offset paging, answered at call time and delivered late, like a response already on its way.
  PageFetcher<T> get offsetEarly => PageFetcher((request) async {
    final page = _window(request);
    await _arrive(request);

    return page;
  });

  List<T> _window(PageRequest request) => store
      .skip(request.pageIndex * request.pageSize)
      .take(request.pageSize)
      .toList(growable: false);

  Future<void> _arrive(PageRequest request) async {
    requests.add(request);
    final attempt = attempts[request.pageIndex] = (attempts[request.pageIndex] ?? 0) + 1;
    final key = (request.pageIndex, attempt);
    await _holds[key]?.future;
    if (failing.contains(key)) throw Exception('page ${request.pageIndex} failed');
  }
}

extension FakeServerKeyset on FakeServer<int> {
  /// Cursor paging on the last id, so an edit elsewhere can't shift it.
  PageFetcher<int> get keyset => PageFetcher.withSignal((request) async {
    await _arrive(request);
    final cursor = request.previousSignal as int?;
    final page = store
        .where((id) => cursor == null || id > cursor)
        .take(request.pageSize)
        .toList(growable: false);

    return (page, page.lastOrNull ?? cursor);
  });
}

/// Lets [holds] through, then drains the frames their pages bring.
Future<void> release(WidgetTester tester, Iterable<Completer<void>> holds) async {
  for (final hold in holds) {
    hold.complete();
  }
  await tester.idle();
  await drain(tester, frames: 12);
}
