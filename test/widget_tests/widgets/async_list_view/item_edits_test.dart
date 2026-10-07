// Test-local fixtures share the file with the scenarios that use them.
// ignore_for_file: prefer-match-file-name

import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../../../support/support.dart';

typedef _Row = ({int id, String label});

void main() {
  feature('ListSmith.async item edits', () {
    scenarioWidgets('an edit while the next page loads keeps both the edit and the paging', (
      tester,
    ) async {
      final server = FakeServer(_range(0, 8));
      final holdCompleter = server.hold(1, attempt: 1);
      final controller = await _pumpList(
        tester,
        fetchPage: server.keysetFetcher,
        itemIdGetter: _byValue,
      );
      await drain(tester);

      controller.remove(0);
      await tester.pump();
      await release(tester, [holdCompleter]);

      check(_shownRows()).deepEquals(_rows(_range(1, 8)));
      // Each page picks up where the one before it ended, so none is asked for twice.
      final cursors = server.requests.skip(1).map((request) => request.previousSignal);
      check(cursors.toSet()).length.equals(cursors.length);
    });

    scenarioOutlineWidgets<void Function(ListSmithController<_Row> controller)>(
      'an edit made while a depth reload runs survives its commit',
      examples: {
        'a removal': (controller) => controller.remove((id: 1, label: 'a')),
        'an update': (controller) => controller.upsert((id: 1, label: 'mine')),
      },
      outline: (tester, edit) async {
        final server = FakeServer<_Row>([(id: 1, label: 'a'), (id: 2, label: 'b')]);
        final controller = await _pumpList<_Row>(
          tester,
          fetchPage: server.offsetEarlyFetcher,
          itemIdGetter: _byRowId,
          labelOf: _rowLabel,
          endPolicy: const FixedPageCountPolicy(pageCount: 1),
          refresh: const PullToRefresh(reload: ReloadToCurrentDepth()),
        );
        await drain(tester);
        final holdCompleter = server.hold(0, attempt: 2);

        unawaited(controller.refresh());
        await drain(tester);
        final beforeEdit = _shownRows();
        edit(controller);
        await tester.pump();
        final afterEdit = _shownRows();
        check(afterEdit).not((it) => it.deepEquals(beforeEdit));
        await release(tester, [holdCompleter]);

        check(server.attempts[0]).equals(2); // the reload did commit
        check(_shownRows()).deepEquals(afterEdit);
      },
    );

    scenarioOutlineWidgets<bool>(
      'a page whose re-fetch fails keeps the edit',
      examples: const {'made before the reload': true, 'made while it runs': false},
      outline: (tester, isBefore) async {
        final server = FakeServer(_range(0, 5));
        final controller = await _pumpList(
          tester,
          fetchPage: server.offsetEarlyFetcher,
          itemIdGetter: _byValue,
          endPolicy: const FixedPageCountPolicy(pageCount: 2),
          refresh: const PullToRefresh(reload: ReloadToCurrentDepth()),
        );
        await drain(tester, frames: 12);
        final holdCompleter = server.hold(0, attempt: 2);
        server.failing.add((0, 2));

        if (isBefore) controller.remove(1);
        unawaited(controller.refresh());
        await drain(tester);
        if (!isBefore) controller.remove(1);
        await tester.pump();
        await release(tester, [holdCompleter]);

        check(server.attempts[1]).equals(2); // the page after it did reload
        check(_shownRows()).deepEquals(_rows([0, 2, 3, 4, 5]));
      },
    );

    scenarioOutlineWidgets<({PaginationEndPolicy endPolicy, List<int> removed})>(
      'the end policy still counts what the server sent after items are removed',
      examples: {
        'StopOnEmptyPagesPolicy, the last page emptied': (
          endPolicy: const StopOnEmptyPagesPolicy(),
          removed: _range(5, 9),
        ),
        'a short-last-page policy, one item removed': (
          endPolicy: const _ShortLastPagePolicy(),
          removed: const [7],
        ),
      },
      outline: (tester, example) async {
        final server = FakeServer(_range(0, 14));
        final scrollController = ScrollController();
        addTearDown(scrollController.dispose);
        final controller = await _pumpList(
          tester,
          fetchPage: server.keysetFetcher,
          itemIdGetter: _byValue,
          pageSize: 5,
          rowHeight: 300, // tall enough that page 2 waits for a scroll
          endPolicy: example.endPolicy,
          scrollController: scrollController,
        );
        await drain(tester, frames: 12);
        check(server.asked(2)).isFalse();

        for (final id in example.removed) {
          server.store.remove(id);
          controller.remove(id);
        }
        for (var pass = 0; pass < 4; pass++) {
          await drain(tester, frames: 6);
          scrollController.jumpTo(scrollController.position.maxScrollExtent);
        }
        await drain(tester, frames: 12);

        check(server.asked(2)).isTrue();
        check(find.text('item 14').evaluate()).isNotEmpty();
      },
    );

    scenarioOutlineWidgets<EmptyPageBehaviour>(
      'removing everything on screen loads the next page, whatever onEmptyPage says',
      examples: const {
        'ShowEmptySurface': ShowEmptySurface(),
        'AdvanceToFirstNonEmpty': AdvanceToFirstNonEmpty(),
      },
      outline: (tester, behaviour) async {
        final server = FakeServer(_range(0, 39));
        final controller = await _pumpList(
          tester,
          fetchPage: server.keysetFetcher,
          itemIdGetter: _byValue,
          pageSize: 20,
          rowHeight: 60, // tall enough that page 1 waits
          onEmptyPage: behaviour,
        );
        await drain(tester, frames: 12);
        check(server.asked(1)).isFalse();

        for (final id in _range(0, 19)) {
          server.store.remove(id);
          controller.remove(id);
        }
        await drain(tester, frames: 12);

        check(_shownRows().firstOrNull).equals('item 20');
      },
    );

    scenarioWidgets('swipe-to-delete with Dismissible works, overlap duplicate included', (
      tester,
    ) async {
      final controller = ListSmithController<int>();
      await _pumpList(
        tester,
        controller: controller,
        fetchPage: pagedFetcher(const [
          [1, 2, 3],
          [3, 4, 5],
        ]),
        itemIdGetter: _byValue,
        endPolicy: const FixedPageCountPolicy(pageCount: 2),
        itemBuilder: (_, item, _) => Dismissible(
          key: ValueKey(item),
          onDismissed: (_) => controller.remove(item),
          child: SizedBox(height: 50, child: Text('item $item')),
        ),
      );
      await drain(tester, frames: 12);

      await tester.drag(find.text('item 3'), const Offset(-700, 0));
      for (var frame = 0; frame < 12; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      check(tester.takeException()).isNull();
      check(_shownRows()).deepEquals(_rows([1, 2, 4, 5]));
    });

    scenarioWidgets('a new item on a grouped list lands in its group, one header per group', (
      tester,
    ) async {
      final controller = await _pumpList<int>(
        tester,
        fetchPage: pagedFetcher(const [
          [0, 1, 10, 11],
        ]),
        itemIdGetter: _byValue,
        pageSize: 4,
        endPolicy: const FixedPageCountPolicy(pageCount: 1),
        grouping: Grouping.by(
          groupBy: (item) => item ~/ 10,
          headerBuilder: (_, key) => Text('group $key'),
        ),
      );
      await drain(tester);

      controller
        ..upsert(12)
        ..upsert(20);
      await drain(tester);

      check(tester.takeException()).isNull();
      check(_shownRows()).deepEquals(_rows([20, 0, 1, 12, 10, 11]));
      for (final key in [0, 1, 2]) {
        check(find.text('group $key').evaluate()).length.equals(1);
      }
    });

    scenarioWidgets('a removal while searching still shows in the feed once the search clears', (
      tester,
    ) async {
      final controller = ListSmithController<int>();
      await _pumpKept(tester, controller, query: '');
      await drain(tester);
      await _pumpKept(tester, controller, query: 'q');
      await settle(tester);
      check(_shownRows()).deepEquals(_rows([2, 4, 6]));

      controller.remove(4);
      await tester.pump();
      await _pumpKept(tester, controller, query: '');
      await settle(tester);

      check(_shownRows()).deepEquals(_rows([1, 2, 3, 5, 6]));
    });

    scenarioWidgets('a refresh while searching does not bring a removed row back afterwards', (
      tester,
    ) async {
      final server = FakeServer(_range(1, 6));
      final feedCatchUpHoldCompleter = server.hold(0, attempt: 2);
      final controller = ListSmithController<int>();
      await _pumpKept(tester, controller, query: '', feed: server.offsetLateFetcher);
      await drain(tester);
      await _pumpKept(tester, controller, query: 'q', feed: server.offsetLateFetcher);
      await settle(tester);

      server.store.remove(4);
      controller.remove(4);
      await controller.refresh(); // the kept feed owes a re-read for this
      await drain(tester, frames: 12);
      await _pumpKept(tester, controller, query: '', feed: server.offsetLateFetcher);
      await settle(tester);

      check(server.attempts[0]).equals(2); // the feed's re-read is still in flight
      check(_shownRows()).deepEquals(_rows([1, 2, 3, 5, 6]));
      await release(tester, [feedCatchUpHoldCompleter]);
      check(_shownRows()).deepEquals(_rows([1, 2, 3, 5, 6]));
    });

    scenarioWidgets('a new item skips the search results and joins the feed', (tester) async {
      final controller = ListSmithController<int>();
      await _pumpKept(tester, controller, query: '');
      await drain(tester);
      await _pumpKept(tester, controller, query: 'q');
      await settle(tester);

      controller.upsert(100);
      await tester.pump();
      check(_shownRows()).deepEquals(_rows([2, 4, 6]));
      await _pumpKept(tester, controller, query: '');
      await settle(tester);

      check(_shownRows()).deepEquals(_rows([100, 1, 2, 3, 4, 5, 6]));
    });

    scenarioOutlineWidgets<Reload>(
      'a refresh after an edit shows the server copy again',
      examples: const {
        'ReloadToCurrentDepth': ReloadToCurrentDepth(),
        'ResetToFirstPage': ResetToFirstPage(),
      },
      outline: (tester, reload) async {
        final server = FakeServer<_Row>([(id: 1, label: 'a'), (id: 2, label: 'b')]);
        final controller = await _pumpList<_Row>(
          tester,
          fetchPage: server.offsetLateFetcher,
          itemIdGetter: _byRowId,
          labelOf: _rowLabel,
          endPolicy: const FixedPageCountPolicy(pageCount: 1),
          refresh: PullToRefresh(reload: reload),
        );
        await drain(tester);
        final before = _shownRows();

        controller.upsert((id: 1, label: 'mine'));
        await tester.pump();
        check(_shownRows()).not((it) => it.deepEquals(before));

        await controller.refresh(); // the save failed, so the server still has the old copy
        await drain(tester, frames: 12);

        check(_shownRows()).deepEquals(before);
      },
    );
  });

  feature('ListSmith.async edits whose save is still out', () {
    Future<(FakeServer<_Row>, ListSmithController<_Row>)> pumpRows(
      WidgetTester tester, {
      Refresh refresh = const PullToRefresh(reload: ReloadToCurrentDepth()),
    }) async {
      final server = FakeServer<_Row>([(id: 1, label: 'a'), (id: 2, label: 'b')]);
      final controller = await _pumpList<_Row>(
        tester,
        fetchPage: server.offsetEarlyFetcher,
        itemIdGetter: _byRowId,
        labelOf: _rowLabel,
        endPolicy: const FixedPageCountPolicy(pageCount: 1),
        refresh: refresh,
      );
      await drain(tester);

      return (server, controller);
    }

    scenarioOutlineWidgets<
      ({Refresh refresh, Future<void> Function(ListSmithController<_Row>) reread})
    >(
      'a draft stays through a re-read while its save is out',
      examples: {
        'a depth reload': (
          refresh: const PullToRefresh(reload: ReloadToCurrentDepth()),
          reread: (controller) => controller.refresh(),
        ),
        'a pull that starts over': (
          refresh: const PullToRefresh(),
          reread: (controller) => controller.refresh(),
        ),
        'invalidate()': (
          refresh: const PullToRefresh(),
          reread: (controller) => controller.invalidate(),
        ),
      },
      outline: (tester, example) async {
        final (server, controller) = await pumpRows(tester, refresh: example.refresh);

        unawaited(controller.upsertAsync((id: 1, label: 'mine'), commit: Completer<_Row>().future));
        await tester.pump();
        await example.reread(controller);
        await drain(tester, frames: 12);

        check(server.attempts[0]).equals(2); // premise: re-read
        check(_shownRows()).deepEquals(_rows(['1 mine', '2 b']));
      },
    );

    scenarioOutlineWidgets<SearchCachePolicy>(
      'a draft stays through a search and back while its save is out',
      examples: const {
        'ReplaceCachePolicy': ReplaceCachePolicy(),
        'KeepCachePolicy': KeepCachePolicy(),
      },
      outline: (tester, cachePolicy) async {
        final server = FakeServer<_Row>([
          (id: 1, label: 'a'),
          (id: 2, label: 'b'),
          (id: 3, label: 'c'),
        ]);
        final controller = ListSmithController<_Row>();
        Future<void> pumpQuery(String query) => _pumpList<_Row>(
          tester,
          controller: controller,
          fetchPage: server.offsetEarlyFetcher,
          itemIdGetter: _byRowId,
          labelOf: _rowLabel,
          endPolicy: const FixedPageCountPolicy(pageCount: 1),
          query: query,
          search: AsyncSearch(
            fetchPage: SearchPageFetcher(
              (_) async => server.store.where((row) => row.id.isOdd).toList(growable: false),
            ),
            cachePolicy: cachePolicy,
          ),
        );
        await pumpQuery('');
        await drain(tester);

        unawaited(controller.upsertAsync((id: 1, label: 'mine'), commit: Completer<_Row>().future));
        await tester.pump();
        await pumpQuery('odd');
        await settle(tester);
        final resultRows = _shownRows();
        await pumpQuery('');
        await settle(tester);
        await drain(tester, frames: 12);

        check(resultRows).deepEquals(_rows(['1 mine', '3 c']));
        check(_shownRows()).deepEquals(_rows(['1 mine', '2 b', '3 c']));
      },
    );

    scenarioOutlineWidgets<
      ({void Function(ListSmithController<_Row>) edit, List<String> shownRows})
    >(
      'a new item and a delete hold through a re-read while their save is out',
      examples: {
        'a new item': (
          edit: (controller) => unawaited(
            controller.upsertAsync((id: 9, label: 'new'), commit: Completer<_Row>().future),
          ),
          shownRows: _rows(['9 new', '1 a', '2 b']),
        ),
        'a delete': (
          edit: (controller) => unawaited(
            controller.removeAsync((id: 2, label: 'b'), commit: Completer<void>().future),
          ),
          shownRows: _rows(['1 a']),
        ),
      },
      outline: (tester, example) async {
        final (server, controller) = await pumpRows(tester);

        example.edit(controller);
        await tester.pump();
        await controller.refresh();
        await drain(tester, frames: 12);

        check(server.attempts[0]).equals(2); // premise: re-read
        check(_shownRows()).deepEquals(example.shownRows);
      },
    );

    scenarioWidgets('a delete stays hidden on pages loaded while its save is out', (tester) async {
      final server = FakeServer(_range(1, 20));
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      final controller = await _pumpList(
        tester,
        fetchPage: server.offsetEarlyFetcher,
        itemIdGetter: _byValue,
        pageSize: 10,
        rowHeight: 300, // tall enough that page 1 waits for a scroll
        scrollController: scrollController,
      );
      await drain(tester, frames: 12);
      check(server.asked(1)).isFalse();

      unawaited(controller.removeAsync(10, commit: Completer<void>().future)); // page 0's last row
      server.store.insert(0, 0); // pushes 10 onto page 1
      await tester.pump();
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
      await drain(tester, frames: 12);

      check(server.asked(1)).isTrue();
      check(find.text('item 9', skipOffstage: false).evaluate()).isNotEmpty(); // 10's spot is built
      check(find.text('item 10', skipOffstage: false).evaluate()).isEmpty();
    });

    scenarioWidgets('once the save answers, what it gave back shows', (tester) async {
      final (server, controller) = await pumpRows(tester);
      final saveCompleter = Completer<_Row>();
      final savedFuture = controller.upsertAsync((
        id: 1,
        label: 'mine',
      ), commit: saveCompleter.future);
      await tester.pump();
      await controller.refresh(); // re-read while the save is out
      await drain(tester, frames: 12);

      server.store[0] = (id: 1, label: 'saved');
      saveCompleter.complete((id: 1, label: 'saved'));
      await savedFuture;
      await tester.pump();

      check(_shownRows()).deepEquals(_rows(['1 saved', '2 b']));
    });

    scenarioOutlineWidgets<
      Future<void> Function(ListSmithController<_Row>, void Function(Exception error) onFailure)
    >(
      'a failed save goes to onFailure instead of throwing',
      examples: {
        'upsertAsync': (controller, onFailure) => controller.upsertAsync(
          (id: 1, label: 'mine'),
          commit: Future.error(Exception('save failed')),
          onFailure: onFailure,
        ),
        'removeAsync': (controller, onFailure) => controller.removeAsync(
          (id: 2, label: 'b'),
          commit: Future.error(Exception('delete failed')),
          onFailure: onFailure,
        ),
      },
      outline: (tester, edit) async {
        final (_, controller) = await pumpRows(tester);
        final reportedErrors = <Exception>[];

        await edit(controller, reportedErrors.add);
        await tester.pump();

        check(reportedErrors).length.equals(1);
        check(_shownRows()).deepEquals(_rows(['1 a', '2 b']));
      },
    );

    scenarioWidgets("a failed save brings back the list's own copy, not the caller's", (
      tester,
    ) async {
      final (server, controller) = await pumpRows(tester);
      server.store[0] = (id: 1, label: 'theirs'); // another writer
      await controller.refresh();
      await drain(tester, frames: 12);
      final saveCompleter = Completer<_Row>();
      final savedFuture = controller.upsertAsync((
        id: 1,
        label: 'mine',
      ), commit: saveCompleter.future);
      await tester.pump();

      saveCompleter.completeError(Exception('save failed'));
      await savedFuture;
      await tester.pump();

      check(_shownRows()).deepEquals(_rows(['1 theirs', '2 b']));
    });

    scenarioWidgets('a failed save of an item no page has loaded leaves nothing on top', (
      tester,
    ) async {
      final server = FakeServer(_range(1, 20));
      final controller = await _pumpList(
        tester,
        fetchPage: server.offsetEarlyFetcher,
        itemIdGetter: _byValue,
        pageSize: 10,
        rowHeight: 300, // tall enough that page 1 waits for a scroll
      );
      await drain(tester, frames: 12);
      check(server.asked(1)).isFalse();
      final saveCompleter = Completer<int>();
      final savedFuture = controller.upsertAsync(15, commit: saveCompleter.future);
      await tester.pump();
      check(_shownRows().first).equals('item 15'); // premise

      saveCompleter.completeError(Exception('save failed'));
      await savedFuture;
      await tester.pump();

      check(_shownRows().first).equals('item 1');
    });

    scenarioWidgets('a save that comes back under another id fails in development', (tester) async {
      final (_, controller) = await pumpRows(tester);
      final savedFuture = controller.upsertAsync((
        id: 9,
        label: 'new',
      ), commit: Future.value((id: 10, label: 'new')));

      await check(savedFuture).throws<AssertionError>();
      await tester.pump();

      check(_shownRows()).deepEquals(_rows(['1 a', '2 b']));
    });

    scenarioWidgets('reset() mid-save drops the draft, and its late answer changes nothing', (
      tester,
    ) async {
      final (_, controller) = await pumpRows(tester);
      final saveCompleter = Completer<_Row>();
      final savedFuture = controller.upsertAsync((
        id: 9,
        label: 'new',
      ), commit: saveCompleter.future);
      await tester.pump();
      check(_shownRows().first).equals('item 9 new');

      await controller.reset();
      await drain(tester, frames: 12);
      final resetRows = _shownRows();
      saveCompleter.complete((id: 9, label: 'new'));
      await savedFuture;
      await tester.pump();

      check(resetRows).deepEquals(_rows(['1 a', '2 b']));
      check(_shownRows()).deepEquals(_rows(['1 a', '2 b']));
    });

    scenarioWidgets('saves answering after the list is gone still finish, failures reported', (
      tester,
    ) async {
      final (_, controller) = await pumpRows(tester);
      final saveCompleter = Completer<_Row>();
      final createCompleter = Completer<_Row>();
      final deleteCompleter = Completer<void>();
      final reportedErrors = <Exception>[];
      final savedFuture = controller.upsertAsync((
        id: 1,
        label: 'mine',
      ), commit: saveCompleter.future);
      final createdFuture = controller.upsertAsync(
        (id: 9, label: 'new'),
        commit: createCompleter.future,
        onFailure: reportedErrors.add,
      );
      final removedFuture = controller.removeAsync(
        (id: 2, label: 'b'),
        commit: deleteCompleter.future,
        onFailure: reportedErrors.add,
      );
      await tester.pump();

      await tester.pumpWidget(const SizedBox()); // the list goes
      saveCompleter.complete((id: 1, label: 'saved'));
      createCompleter.completeError(Exception('save failed'));
      deleteCompleter.completeError(Exception('delete failed'));
      await (savedFuture, createdFuture, removedFuture).wait;

      check(reportedErrors).length.equals(2);
    });
  });
}

Future<ListSmithController<T>> _pumpList<T extends Object>(
  WidgetTester tester, {
  required PageFetcher<T> fetchPage,
  required ItemIdGetter<T> itemIdGetter,
  ListSmithController<T>? controller,
  String Function(T item)? labelOf,
  int pageSize = 3,
  PaginationEndPolicy endPolicy = const StopOnEmptyPagesPolicy(),
  EmptyPageBehaviour onEmptyPage = const ShowEmptySurface(),
  Refresh refresh = const PullToRefresh(),
  Grouping<T>? grouping,
  Search<T> search = const NoSearch(),
  String query = '',
  double rowHeight = 20,
  ScrollController? scrollController,
  ItemBuilder<T>? itemBuilder,
}) async {
  final handle = controller ?? ListSmithController<T>();
  await pumpListSmith(
    tester,
    ListSmith<T>.async(
      fetchPage: fetchPage,
      pageSize: pageSize,
      endPolicy: endPolicy,
      onEmptyPage: onEmptyPage,
      refresh: refresh,
      itemIdGetter: itemIdGetter,
      grouping: grouping,
      search: search,
      query: query,
      searchDebounce: const Duration(milliseconds: 20),
      scroll: ListScrollConfig(controller: scrollController),
      controller: handle,
      itemBuilder:
          itemBuilder ??
          (_, item, _) =>
              SizedBox(height: rowHeight, child: Text('item ${labelOf?.call(item) ?? item}')),
    ),
  );

  return handle;
}

/// A feed kept by [KeepCachePolicy] under a search that returns the even rows.
Future<void> _pumpKept(
  WidgetTester tester,
  ListSmithController<int> controller, {
  required String query,
  PageFetcher<int>? feed,
}) => _pumpList(
  tester,
  controller: controller,
  fetchPage: feed ?? pagedFetcher([_range(1, 6)]),
  itemIdGetter: _byValue,
  pageSize: 6,
  endPolicy: const FixedPageCountPolicy(pageCount: 1),
  query: query,
  search: AsyncSearch(
    fetchPage: pagedSearchFetcher(const [
      [2, 4, 6],
    ]),
    cachePolicy: const KeepCachePolicy(),
  ),
);

/// The rows on screen, top to bottom.
List<String> _shownRows() => find
    .textContaining(RegExp('^item '))
    .evaluate()
    .map((element) => (element.widget as Text).data)
    .nonNulls
    .toList(growable: false);

List<String> _rows(Iterable<Object> labels) =>
    labels.map((label) => 'item $label').toList(growable: false);

List<int> _range(int from, int to) => List.generate(to - from + 1, (index) => from + index);

Object _byValue(Object item) => item;

Object _byRowId(_Row item) => item.id;

String _rowLabel(_Row item) => '${item.id} ${item.label}';

final class const _ShortLastPagePolicy() extends PaginationEndPolicy {
  @override
  bool hasReachedEnd(EndContext context) =>
      context.pageCount > 0 && context.lastPageItemCount < context.pageSize;
}
