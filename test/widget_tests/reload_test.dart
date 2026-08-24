import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../support/support.dart';

void main() {
  feature('ListSmith.async ReloadToCurrentDepth', () {
    // Each page yields one item whose value encodes `page * 1000 + attempt`, so a test can tell a
    // freshly-reloaded page (attempt 2) from a kept-old one (attempt 1), and `attempts` records how
    // many times each page index was fetched.
    ({PageFetcher<int> fetchPage, Map<int, int> attempts}) valuedFetcher({int? failPageOnReload}) {
      final attempts = <int, int>{};
      final fetchPage = PageFetcher<int>((request) async {
        final attempt = attempts[request.pageIndex] = (attempts[request.pageIndex] ?? 0) + 1;
        if (request.pageIndex == failPageOnReload && attempt == 2) throw Exception('reload boom');

        return [request.pageIndex * 1000 + attempt];
      });

      return (fetchPage: fetchPage, attempts: attempts);
    }

    Future<void> pullToRefresh(WidgetTester tester, Finder anchor) async {
      await tester.fling(anchor, const Offset(0, 300), 1000);
      for (var frame = 0; frame < 10; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await drain(tester, frames: 16);
    }

    scenarioWidgets('re-fetches every loaded page, keeping depth', (tester) async {
      final fetcher = valuedFetcher();

      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: fetcher.fetchPage,
          endPolicy: const FixedPageCountPolicy(pageCount: 3),
          refresh: const PullToRefresh(reload: ReloadToCurrentDepth(concurrency: null)),
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await drain(tester, frames: 12);
      check(fetcher.attempts).deepEquals({0: 1, 1: 1, 2: 1});

      await pullToRefresh(tester, find.text('item 1'));

      // All three loaded pages were fetched again, and page 0 now shows its fresh value (attempt 2).
      check(fetcher.attempts).deepEquals({0: 2, 1: 2, 2: 2});
      check(find.text('item 2').evaluate()).length.equals(1);
      check(find.text('item 1').evaluate()).length.equals(0);
    });

    scenarioWidgets('best-effort keeps the failed page old and commits the rest fresh', (
      tester,
    ) async {
      final fetcher = valuedFetcher(failPageOnReload: 1);

      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: fetcher.fetchPage,
          endPolicy: const FixedPageCountPolicy(pageCount: 3),
          refresh: const PullToRefresh(reload: ReloadToCurrentDepth(concurrency: null)),
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await drain(tester, frames: 12);

      await pullToRefresh(tester, find.text('item 1'));

      // Pages 0 and 2 reloaded (fresh attempt-2 values); page 1's fetch failed so its old value stays.
      check(find.text('item 2').evaluate()).length.equals(1); // page 0 fresh
      check(find.text('item 1001').evaluate()).length.equals(1); // page 1 kept old
      check(find.text('item 2002').evaluate()).length.equals(1); // page 2 fresh
      check(find.text('item 1002').evaluate()).length
          .equals(0); // page 1's failed fresh never shows
    });

    scenarioWidgets('all-or-nothing keeps every page old when one fails', (tester) async {
      final fetcher = valuedFetcher(failPageOnReload: 1);

      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: fetcher.fetchPage,
          endPolicy: const FixedPageCountPolicy(pageCount: 3),
          refresh: const PullToRefresh(
            reload: ReloadToCurrentDepth(concurrency: null, onError: .allOrNothing),
          ),
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await drain(tester, frames: 12);

      await pullToRefresh(tester, find.text('item 1'));

      // One page failed, so nothing is committed: the pre-refresh values all remain.
      check(find.text('item 1').evaluate()).length.equals(1); // page 0 still old
      check(find.text('item 1001').evaluate()).length.equals(1); // page 1 still old
      check(find.text('item 2001').evaluate()).length.equals(1); // page 2 still old
      check(find.text('item 2').evaluate()).length.equals(0); // no fresh value committed
    });

    scenarioWidgets('a withSignal source commits the whole chain when every page succeeds', (
      tester,
    ) async {
      final attempts = <int, int>{};
      final cursorsSeen = <int, Object?>{};
      final fetchPage = PageFetcher<int>.withSignal((request) async {
        final pageIndex = request.pageIndex;
        final attempt = attempts.update(pageIndex, (count) => count + 1, ifAbsent: () => 1);
        cursorsSeen[pageIndex] = request.previousSignal;

        return ([pageIndex * 1000 + attempt], pageIndex < 2 ? 'cursor$pageIndex' : null);
      });

      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: fetchPage,
          endPolicy: const StopOnNullSignalPolicy(),
          refresh: const PullToRefresh(reload: ReloadToCurrentDepth()),
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await drain(tester, frames: 12);
      check(attempts).deepEquals({0: 1, 1: 1, 2: 1});

      await pullToRefresh(tester, find.text('item 1'));

      // The sibling scenario always fails mid-chain, so it returns before committing and never
      // covers this. Here every page succeeds, so the reload reaches its commit.
      check(attempts).deepEquals({0: 2, 1: 2, 2: 2});
      check(find.text('item 2').evaluate()).length.equals(1);
      check(find.text('item 1002').evaluate()).length.equals(1);
      check(find.text('item 2002').evaluate()).length.equals(1);
      // Old values all replaced, so the commit was whole and not page-by-page.
      check(find.text('item 1').evaluate()).length.equals(0);
      check(find.text('item 2001').evaluate()).length.equals(0);
      // Each page was handed the previous page's fresh cursor, so the chain was rebuilt in order.
      check(cursorsSeen[0]).isNull();
      check(cursorsSeen[1]).equals('cursor0');
      check(cursorsSeen[2]).equals('cursor1');
    });

    scenarioWidgets('a withSignal commit drops a page still in flight', (tester) async {
      final hold = Completer<void>();
      final attempts = <int, int>{};
      final fetchPage = PageFetcher<int>.withSignal((request) async {
        final pageIndex = request.pageIndex;
        final attempt = attempts.update(pageIndex, (count) => count + 1, ifAbsent: () => 1);
        // Page 3 is held on its first attempt only, so the reload's own walk never blocks.
        if (pageIndex == 3 && attempt == 1) await hold.future;

        return ([pageIndex * 1000 + attempt], 'cursor$pageIndex');
      });

      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: fetchPage,
          endPolicy: const FixedPageCountPolicy(pageCount: 4),
          refresh: const PullToRefresh(reload: ReloadToCurrentDepth()),
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await drain(tester, frames: 12);

      // Premise: pages 0-2 are in and page 3 is held, so the reload's depth is 3.
      check(attempts[3]).equals(1);
      check(find.text('item 3001').evaluate()).length.equals(0);

      await pullToRefresh(tester, find.text('item 1'));
      hold.complete();
      await tester.idle();
      await drain(tester, frames: 16);

      // The held page carried attempt 1, from before the reload. It is dropped, and page 3 is asked
      // again so its attempt-2 body lands on top of the reloaded chain instead.
      check(find.text('item 3001').evaluate()).length.equals(0);
      check(find.text('item 3002').evaluate()).length.equals(1);
      check(find.text('item 2').evaluate()).length.equals(1);
    });

    scenarioWidgets('a withSignal source reloads sequentially and atomically', (tester) async {
      final attempts = <int, int>{};
      final fetchPage = PageFetcher<int>.withSignal((request) async {
        final pageIndex = request.pageIndex;
        final attempt = attempts.update(pageIndex, (count) => count + 1, ifAbsent: () => 1);
        if (pageIndex == 1 && attempt == 2) throw Exception('reload boom');

        return ([pageIndex * 1000 + attempt], pageIndex < 2 ? 'cursor$pageIndex' : null);
      });

      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: fetchPage,
          endPolicy: const StopOnNullSignalPolicy(),
          // concurrency is ignored for a signal source; the reload is sequential regardless.
          refresh: const PullToRefresh(reload: ReloadToCurrentDepth(concurrency: null)),
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await drain(tester, frames: 12);
      check(attempts).deepEquals({0: 1, 1: 1, 2: 1});

      await pullToRefresh(tester, find.text('item 1'));

      // Sequential: it walked 0, hit the failure at 1, and never reached 2 (attempt still 1). Atomic:
      // the old values all remain (the broken chain committed nothing).
      check(attempts).deepEquals({0: 2, 1: 2, 2: 1});
      check(find.text('item 1').evaluate()).length.equals(1); // page 0 old kept
      check(find.text('item 2').evaluate()).length.equals(0); // no fresh commit
    });
  });
}
