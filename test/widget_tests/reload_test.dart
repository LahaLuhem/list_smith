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
      final fetchPage = PageFetcher<int>((pageIndex, _) async {
        final attempt = attempts[pageIndex] = (attempts[pageIndex] ?? 0) + 1;
        if (pageIndex == failPageOnReload && attempt == 2) throw Exception('reload boom');

        return [pageIndex * 1000 + attempt];
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
      check(
        find.text('item 1002').evaluate(),
      ).length.equals(0); // page 1's failed fresh never shows
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

    scenarioWidgets('a withSignal source reloads sequentially and atomically', (tester) async {
      final attempts = <int, int>{};
      final fetchPage = PageFetcher<int>.withSignal((pageIndex, _, _) async {
        final attempt = attempts[pageIndex] = (attempts[pageIndex] ?? 0) + 1;
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
