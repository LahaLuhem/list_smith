// A test-local spinning indicator shares the file with the scenario that drives it.
// ignore_for_file: prefer-match-file-name

import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../support/support.dart';

void main() {
  feature('ListSmith.async surface paths', () {
    scenarioWidgets('a failing later page shows the new-page error surface', (tester) async {
      await _pumpAsync(
        tester,
        fetchPage: PageFetcher((request) async {
          if (request.pageIndex == 0) return const [1, 2, 3];

          throw Exception('later page');
        }),
        surfaces: AsyncListSurfaces(newPageErrorBuilder: (_, _, _) => const Text('later failed')),
      );
      await drain(tester);

      // Page 0's items stay while the failed page 1 shows its own error footer.
      check(find.text('item 1').evaluate()).length.equals(1);
      check(find.text('later failed').evaluate()).length.equals(1);
    });

    scenarioWidgets('a separator builder renders the separated list', (tester) async {
      await _pumpAsync(
        tester,
        fetchPage: PageFetcher(
          (request) async => request.pageIndex == 0 ? const [1, 2, 3] : const <int>[],
        ),
        separatorBuilder: (_, _) => const Text('sep'),
      );
      await drain(tester);

      check(find.text('item 1').evaluate()).length.equals(1);
      // Separators fall between the items (and before the end-of-list footer).
      check(find.text('sep').evaluate()).length.isGreaterThan(1);
    });

    scenarioWidgets('an idle list under the neutral pull indicator requests no frames', (
      tester,
    ) async {
      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: pagedFetcher(const [
            [1, 2, 3],
          ]),
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await drain(tester);
      // Loaded to the end, so no page-loading spinner is left either.
      check(find.text('No more items').evaluate()).length.equals(1);

      await tester.pump(const Duration(seconds: 1));

      check(tester.binding.hasScheduledFrame).isFalse();
    });

    scenarioWidgets('a custom indicator is built only while a pull is in progress', (tester) async {
      final hold = Completer<List<int>>();
      var firstPageFetches = 0;
      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: PageFetcher((request) {
            if (request.pageIndex > 0) return Future.value(const <int>[]);
            firstPageFetches++;

            return firstPageFetches == 1 ? Future.value(const [1, 2, 3]) : hold.future;
          }),
          refresh: PullToRefresh(
            // A depth reload waits on its fetches, so the held one keeps the refresh running.
            reload: const ReloadToCurrentDepth(),
            indicatorBuilder: (_, _) => const _SpinningIndicator(),
          ),
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );
      await drain(tester);
      check(find.text('item 1').evaluate()).length.equals(1);
      check(find.byType(_SpinningIndicator).evaluate()).isEmpty();

      await pullToRefresh(tester, find.text('item 1'));
      check(firstPageFetches).equals(2);
      check(find.byType(_SpinningIndicator).evaluate()).length.equals(1);

      hold.complete(const [1, 2, 3]);
      // Timed frames, so the indicator's animation back to rest actually runs.
      for (var frame = 0; frame < 5; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      check(find.byType(_SpinningIndicator).evaluate()).isEmpty();
      check(tester.binding.hasScheduledFrame).isFalse();
    });

    scenarioWidgets('the neutral spinner repaints when the ambient colour changes', (tester) async {
      final hold = Completer<List<int>>();
      Widget build(Color colour) => DefaultTextStyle(
        style: TextStyle(color: colour),
        child: ListSmith.async(
          fetchPage: PageFetcher(
            (request) => request.pageIndex == 0 ? hold.future : Future.value(const <int>[]),
          ),
          refresh: const NoRefresh(),
          itemBuilder: (_, item, _) => Text('item $item'),
        ),
      );

      // Held on the 1st page, so the neutral spinner is what is on screen.
      await pumpListSmith(tester, build(const Color(0xFFFF0000)));
      await drain(tester);
      check(find.byType(CustomPaint).evaluate()).isNotEmpty();

      // Re-pump under a different ambient colour: the arc painter has to notice and repaint.
      await pumpListSmith(tester, build(const Color(0xFF0000FF)));
      await drain(tester);
      check(find.byType(CustomPaint).evaluate()).isNotEmpty();

      hold.complete(const [1]);
      await tester.idle();
      await drain(tester);
      check(find.text('item 1').evaluate()).length.equals(1);
    });
  });

  feature('ListSmith.sync rebuild and layout', () {
    scenarioWidgets('replacing the items list after build re-materialises and re-filters', (
      tester,
    ) async {
      await _pumpSync(tester, items: const ['apple', 'banana'], searchBy: containsIgnoreCase);
      await tester.pump();
      check(find.text('apple').evaluate()).length.equals(1);

      await _pumpSync(tester, items: const ['cherry', 'date'], searchBy: containsIgnoreCase);
      await tester.pump();

      check(find.text('cherry').evaluate()).length.equals(1);
      check(find.text('apple').evaluate()).length.equals(0);
    });

    scenarioWidgets('changing the query after build commits a new filter', (tester) async {
      // Same const list on both pumps, so only the query changes (isolates the query path).
      const items = ['apple', 'banana'];
      await _pumpSync(tester, items: items, searchBy: containsIgnoreCase);
      await tester.pump();
      check(find.text('banana').evaluate()).length.equals(1);

      await _pumpSync(tester, items: items, searchBy: containsIgnoreCase, query: 'app');
      // Fire the zero-duration debounce timer so the new query commits.
      await tester.pump(const Duration(milliseconds: 1));

      check(find.text('apple').evaluate()).length.equals(1);
      check(find.text('banana').evaluate()).length.equals(0);
    });

    scenarioWidgets('applies a custom cache extent', (tester) async {
      await _pumpSync(
        tester,
        items: const ['apple'],
        searchBy: containsIgnoreCase,
        scroll: const ListScrollConfig(cacheExtent: 250),
      );
      await tester.pump();

      check(find.text('apple').evaluate()).length.equals(1);
    });

    scenarioWidgets('a separator builder renders the separated list', (tester) async {
      await _pumpSync(
        tester,
        items: const ['apple', 'banana'],
        searchBy: containsIgnoreCase,
        separatorBuilder: (_, _) => const Text('sep'),
      );
      await tester.pump();

      check(find.text('apple').evaluate()).length.equals(1);
      // 2 items yield one separator.
      check(find.text('sep').evaluate()).length.equals(1);
    });
  });
}

Future<void> _pumpAsync(
  WidgetTester tester, {
  required PageFetcher<int> fetchPage,
  AsyncListSurfaces surfaces = const AsyncListSurfaces(),
  IndexedWidgetBuilder? separatorBuilder,
}) => pumpListSmith(
  tester,
  ListSmith.async(
    fetchPage: fetchPage,
    surfaces: surfaces,
    separatorBuilder: separatorBuilder,
    refresh: const NoRefresh(),
    itemBuilder: (_, item, _) => Text('item $item'),
  ),
);

Future<void> _pumpSync(
  WidgetTester tester, {
  required List<String> items,
  required SyncSearchPredicate<String> searchBy,
  String query = '',
  IndexedWidgetBuilder? separatorBuilder,
  ListScrollConfig scroll = const ListScrollConfig(),
}) => pumpListSmith(
  tester,
  ListSmith.sync(
    items: items,
    searchBy: searchBy,
    query: query,
    separatorBuilder: separatorBuilder,
    scroll: scroll,
    itemBuilder: (_, item, _) => Text(item),
  ),
);

/// Spins for as long as it's mounted, so one left behind at rest keeps asking for frames.
class _SpinningIndicator extends StatefulWidget {
  const new();

  @override
  State<_SpinningIndicator> createState() => _SpinningIndicatorState();
}

class _SpinningIndicatorState extends State<_SpinningIndicator>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))
    ..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RotationTransition(turns: _controller, child: const Text('spinner'));
}
