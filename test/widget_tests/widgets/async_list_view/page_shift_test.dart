import 'dart:async';
import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../../../support/support.dart';

void main() {
  feature('ListSmith.async paging on after removals', () {
    scenarioOutlineWidgets<void Function(ListSmithController<int> controller)>(
      'the rows a removal pulls up still show when the next page loads',
      examples: {
        'its save already answered': (controller) => controller.remove(1),
        'its save still out': (controller) =>
            unawaited(controller.removeAsync(1, commit: Completer<void>().future)),
      },
      outline: (tester, remove) async {
        final server = FakeServer(_range(0, 14));
        final scrollController = ScrollController();
        addTearDown(scrollController.dispose);
        final controller = await _pumpList(
          tester,
          fetchPage: server.offsetLateFetcher,
          scrollController: scrollController,
        );
        check(server.asked(3)).isFalse(); // page 3 waits for a scroll

        server.store.remove(1);
        remove(controller);
        await tester.pump();

        check(await _allShownItems(tester, scrollController)).deepEquals(server.store);
      },
    );

    scenarioWidgets('the same while the removed row is still animating out', (tester) async {
      final server = FakeServer(_range(0, 14));
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      final controller = await _pumpList(
        tester,
        fetchPage: server.offsetLateFetcher,
        scrollController: scrollController,
        editTransition: EditTransition(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) =>
              SizeTransition(sizeFactor: animation, alignment: .topStart, child: child),
        ),
      );

      server.store.remove(1);
      controller.remove(1);
      await tester.pump(); // the exit starts a frame on
      await _scrollToEnd(tester, scrollController); // no time passes, so the exit is still running
      final isAskedMidExit = server.asked(3);
      await tester.pump(const Duration(milliseconds: 400));

      check(isAskedMidExit).isTrue();
      check(await _allShownItems(tester, scrollController)).deepEquals(server.store);
    });

    scenarioWidgets('removing every row on screen shows the rows after them, not the empty one', (
      tester,
    ) async {
      final server = FakeServer(_range(0, 14));
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      final controller = await _pumpList(
        tester,
        fetchPage: server.offsetLateFetcher,
        scrollController: scrollController,
      );

      for (final item in _range(0, 8)) {
        server.store.remove(item);
        controller.remove(item);
      }
      await tester.idle();
      await drain(tester, frames: 12);

      check(await _allShownItems(tester, scrollController)).deepEquals(server.store);
    });

    scenarioWidgets('the same in search results', (tester) async {
      final server = FakeServer(_range(0, 28));
      final searchPageIndexes = <int>[];
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      final controller = await _pumpList(
        tester,
        fetchPage: server.offsetLateFetcher,
        scrollController: scrollController,
        search: AsyncSearch(fetchPage: _evenRowsFetcher(server, searchPageIndexes)),
        query: 'even',
      );
      check(searchPageIndexes).not((it) => it.contains(3));

      server.store.remove(4);
      controller.remove(4);
      await tester.pump();

      check(await _allShownItems(tester, scrollController))
          .deepEquals(server.store.where((item) => item.isEven));
    });

    scenarioWidgets('the same in a feed kept while searching, once it comes back', (tester) async {
      final server = FakeServer(_range(0, 14));
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      final controller = ListSmithController<int>();
      Future<void> pumpWithQuery(String query) async {
        await _pumpList(
          tester,
          fetchPage: server.offsetLateFetcher,
          scrollController: scrollController,
          controller: controller,
          search: AsyncSearch(
            fetchPage: _evenRowsFetcher(server, []),
            cachePolicy: const KeepCachePolicy(),
          ),
          query: query,
        );
        await settle(tester);
      }

      await pumpWithQuery('');
      await pumpWithQuery('even');
      server.store.remove(2);
      controller.remove(2);
      await pumpWithQuery('');

      check(await _allShownItems(tester, scrollController)).deepEquals(server.store);
    });

    scenarioWidgets('with a removal still saving, the list still stops at its 1st empty page', (
      tester,
    ) async {
      final server = FakeServer(_range(0, 14));
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      final controller = await _pumpList(
        tester,
        fetchPage: server.offsetLateFetcher,
        scrollController: scrollController,
      );

      server.store.remove(1);
      unawaited(controller.removeAsync(1, commit: Completer<void>().future));
      await tester.pump();
      await _scrollToEnd(tester, scrollController);

      final firstEmptyPageIndex = (server.store.length / _pageSize).ceil();
      check(server.asked(firstEmptyPageIndex)).isTrue();
      check(server.asked(firstEmptyPageIndex + 1)).isFalse();
    });
  });
}

const _pageSize = 3;

/// Tall enough that pages 0 to 2 load at mount and page 3 waits for a scroll.
const _rowHeight = 300.0;

Future<ListSmithController<int>> _pumpList(
  WidgetTester tester, {
  required PageFetcher<int> fetchPage,
  required ScrollController scrollController,
  ListSmithController<int>? controller,
  EditTransition editTransition = const NoEditTransition(),
  Search<int> search = const NoSearch(),
  String query = '',
}) async {
  final handle = controller ?? ListSmithController<int>();
  await pumpListSmith(
    tester,
    ListSmith<int>.async(
      fetchPage: fetchPage,
      pageSize: _pageSize,
      itemIdGetter: (item) => item,
      editTransition: editTransition,
      search: search,
      query: query,
      searchDebounce: const Duration(milliseconds: 20),
      scroll: ListScrollConfig(controller: scrollController),
      controller: handle,
      itemBuilder: (_, item, _) => SizedBox(height: _rowHeight, child: Text('item $item')),
    ),
  );
  await drain(tester, frames: 12);

  return handle;
}

/// Search over [server]'s even rows by offset, noting each page it's asked for in [pageIndexes].
SearchPageFetcher<int> _evenRowsFetcher(FakeServer<int> server, List<int> pageIndexes) =>
    SearchPageFetcher((request) async {
      pageIndexes.add(request.pageIndex);

      return server.store
          .where((item) => item.isEven)
          .skip(request.pageIndex * request.pageSize)
          .take(request.pageSize);
    });

/// Jumps to the end until it stops growing, since the list only knows its end once rows are laid out.
Future<void> _scrollToEnd(WidgetTester tester, ScrollController scrollController) async {
  double? lastMaxScrollExtent;
  for (var pass = 0; pass < 20; pass++) {
    final maxScrollExtent = scrollController.position.maxScrollExtent;
    if (maxScrollExtent == lastMaxScrollExtent) return;
    lastMaxScrollExtent = maxScrollExtent;
    scrollController.jumpTo(maxScrollExtent);
    await tester.idle();
    await drain(tester);
  }
}

/// Every row the list shows once it has reached its end, top to bottom, read a screen at a time.
Future<List<int>> _allShownItems(WidgetTester tester, ScrollController scrollController) async {
  await _scrollToEnd(tester, scrollController);
  scrollController.jumpTo(0);
  await tester.pump();
  final shownItems = <int>{};
  while (true) {
    shownItems.addAll(
      find
          .textContaining(RegExp('^item '))
          .evaluate()
          .map((element) => int.parse((element.widget as Text).data!.split(' ').last)),
    );
    final position = scrollController.position;
    if (position.pixels >= position.maxScrollExtent) return shownItems.toList(growable: false);
    scrollController.jumpTo(
      math.min(position.pixels + position.viewportDimension, position.maxScrollExtent),
    );
    await tester.pump();
  }
}

List<int> _range(int from, int to) => List.generate(to - from + 1, (index) => from + index);
