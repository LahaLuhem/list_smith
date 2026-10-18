// Test-local fixtures share the file with the scenarios that use them.
// ignore_for_file: prefer-match-file-name

import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../../../support/support.dart';

typedef _Row = ({int id, String team, String name});

void main() {
  feature('ListSmith.async sorted placement', () {
    scenarioOutlineWidgets<_Edit>(
      'an edit lands where the order puts it',
      examples: {
        'a rename inside the loaded rows': (server, controller) =>
            _rename(server, controller, 1, 'n11'),
        'a new item inside them': (server, controller) =>
            _create(server, controller, (id: 100, team: 'A', name: 'n05')),
      },
      outline: (tester, edit) async {
        final server = FakeServer(_rows());
        final scrollController = _scrollController();
        final controller = await _pumpSorted(tester, server, scrollController);

        edit(server, controller);
        await tester.pump();

        check(await _allShownNames(tester, scrollController)).deepEquals(_namesOf(server));
      },
    );

    scenarioOutlineWidgets<({_FetcherGetter fetcherOf, _Edit edit})>(
      'a row sorting after the loaded ones waits for its page',
      examples: {
        'a new item': (
          fetcherOf: (server) => server.offsetLateFetcher,
          edit: (server, controller) =>
              _create(server, controller, (id: 100, team: 'C', name: 'n99')),
        ),
        'a rename, paged by the last row': (
          fetcherOf: _keysetByName,
          edit: (server, controller) => _rename(server, controller, 1, 'n99'),
        ),
      },
      outline: (tester, example) async {
        final server = FakeServer(_rows());
        final scrollController = _scrollController();
        final controller = await _pumpSorted(
          tester,
          server,
          scrollController,
          fetchPage: example.fetcherOf(server),
        );

        example.edit(server, controller);
        await tester.pump();

        check(find.text('row n99').evaluate()).isEmpty();
        check(await _allShownNames(tester, scrollController)).deepEquals(_namesOf(server));
      },
    );

    scenarioOutlineWidgets<({PaginationEndPolicy endPolicy, int shownCount})>(
      'once the data has ended, a row sorting last shows last, but never past a cap',
      examples: const {
        'the data ran out': (endPolicy: StopOnEmptyPagesPolicy(), shownCount: 16),
        'a cap of 3 pages': (endPolicy: FixedPageCountPolicy(pageCount: 3), shownCount: 9),
      },
      outline: (tester, example) async {
        final server = FakeServer(_rows());
        final scrollController = _scrollController();
        final controller = await _pumpSorted(
          tester,
          server,
          scrollController,
          rowHeight: _shortRowHeight,
          endPolicy: example.endPolicy,
        );

        _create(server, controller, (id: 100, team: 'C', name: 'n99'));
        await tester.pump();

        check(await _allShownNames(tester, scrollController))
            .deepEquals(_namesOf(server).take(example.shownCount));
      },
    );

    scenarioWidgets('the rows a move pulls up still show when the next page loads', (tester) async {
      final server = FakeServer(_rows());
      final scrollController = _scrollController();
      final controller = await _pumpSorted(tester, server, scrollController);

      _rename(server, controller, 1, 'n99');
      await tester.pump();

      check(await _allShownNames(tester, scrollController)).deepEquals(_namesOf(server));
    });

    scenarioWidgets('the same for a new item renamed once a later page loaded', (tester) async {
      final server = FakeServer(_rows());
      final pageHoldCompleter = server.hold(4, attempt: 1);
      final scrollController = _scrollController();
      final controller = await _pumpSorted(tester, server, scrollController);
      _create(server, controller, (id: 100, team: 'A', name: 'n03'));
      await tester.pump();
      await scrollToEnd(tester, scrollController);
      check(server.asked(4)).isTrue(); // premise: page 3 was read after it, page 4 waits

      _rename(server, controller, 100, 'n99');
      await tester.pump();
      await release(tester, [pageHoldCompleter]);

      check(await _allShownNames(tester, scrollController)).deepEquals(_namesOf(server));
    });

    scenarioOutlineWidgets<({String name, int pageCount})>(
      'the same when it lands mid-reload',
      examples: const {
        'past the reloaded pages': (name: 'n99', pageCount: 2),
        'into a later reloaded page': (name: 'n17', pageCount: 3),
      },
      outline: (tester, example) async {
        final server = FakeServer(_rows());
        final scrollController = _scrollController();
        final controller = await _pumpSorted(
          tester,
          server,
          scrollController,
          rowHeight: _shortRowHeight,
          endPolicy: FixedPageCountPolicy(pageCount: example.pageCount),
        );
        final secondPageHoldCompleter = server.hold(1, attempt: 2);
        unawaited(controller.invalidate());
        await tester.idle();
        await drain(tester, frames: 4);

        _rename(server, controller, 1, example.name); // after page 0 is read, before page 1 is
        await tester.pump();
        await release(tester, [secondPageHoldCompleter]);

        check(await _allShownNames(tester, scrollController))
            .deepEquals(_namesOf(server).take(example.pageCount * 3));
      },
    );

    scenarioWidgets('the same for a row created before the reload', (tester) async {
      final server = FakeServer(_rows());
      final scrollController = _scrollController();
      final controller = await _pumpSorted(
        tester,
        server,
        scrollController,
        rowHeight: _shortRowHeight,
        endPolicy: const FixedPageCountPolicy(pageCount: 2),
      );
      _create(server, controller, (id: 100, team: 'A', name: 'n03'));
      await tester.pump();
      final secondPageHoldCompleter = server.hold(1, attempt: 2);
      unawaited(controller.invalidate());
      await tester.idle();
      await drain(tester, frames: 4);

      _rename(server, controller, 100, 'n99'); // after page 0 is read, before page 1 is
      await tester.pump();
      await release(tester, [secondPageHoldCompleter]);

      check(await _allShownNames(tester, scrollController)).deepEquals(_namesOf(server).take(6));
    });

    scenarioWidgets('an edit that leaves its row in place reads no page again', (tester) async {
      final server = FakeServer(_rows());
      final scrollController = _scrollController();
      final controller = await _pumpSorted(tester, server, scrollController);
      check(server.asked(3)).isFalse(); // page 3 waits for a scroll

      final row = server.store[1];
      final retaggedRow = (id: row.id, team: 'Z', name: row.name);
      server.store[1] = retaggedRow;
      controller.upsert(retaggedRow);
      await tester.pump();
      await scrollToEnd(tester, scrollController);

      check(server.attempts.values).every((it) => it.equals(1));
    });

    scenarioWidgets('a row placement moves keeps its state', (tester) async {
      final server = FakeServer(_rows());
      final controller = await _pumpSorted(
        tester,
        server,
        _scrollController(),
        itemBuilder: (_, row, _) => ToggleRow(row.id),
      );
      await tester.tap(find.text('off 1'));
      await tester.pump();

      _rename(server, controller, 1, 'n11');
      await tester.pump();

      final shownRows = shownToggleRows();
      check(shownRows.indexOf('on 1')).equals(shownRows.indexOf('off 4') + 1);
    });

    scenarioOutlineWidgets<({List<_Row> rows, Comparator<_Row> comparator})>(
      'a page out of the order is reported',
      examples: {
        'the order runs backwards': (rows: _rows(), comparator: (a, b) => _byName(b, a)),
        'the order has no tie-break': (
          rows: _rows()..[2] = (id: 2, team: 'A', name: 'n04'),
          comparator: (a, b) => a.name.compareTo(b.name),
        ),
      },
      outline: (tester, example) async {
        final server = FakeServer(example.rows..sort(_byName));
        await _pumpSorted(tester, server, _scrollController(), order: SortedBy(example.comparator));

        check(tester.takeException()).isNotNull();
      },
    );

    scenarioWidgets('search results keep their own order', (tester) async {
      final server = FakeServer(_rows());
      final controller = await _pumpSorted(
        tester,
        server,
        _scrollController(),
        search: AsyncSearch(
          fetchPage: SearchPageFetcher(
            (request) async => server.store.reversed
                .skip(request.pageIndex * request.pageSize)
                .take(request.pageSize),
          ),
        ),
        query: 'q',
      );
      await settle(tester);

      controller.upsert((id: 13, team: 'C', name: 'n01'));
      await tester.pump();

      check(tester.takeException()).isNull();
      // In place is 2nd here. The feed's order would put it 1st.
      check(tester.getTopLeft(find.text('row n01')).dy)
          .isGreaterThan(tester.getTopLeft(find.text('row n30')).dy);
    });

    scenarioWidgets("an order that doesn't sort by group first trips grouping's check", (
      tester,
    ) async {
      final server = FakeServer(_rows()..sort(_byTeamThenName));
      final controller = await _pumpSorted(
        tester,
        server,
        _scrollController(),
        rowHeight: _shortRowHeight,
        grouping: Grouping.by(groupBy: (row) => row.team, headerBuilder: (_, team) => Text(team)),
      );

      _rename(server, controller, 1, 'n13', comparator: _byTeamThenName);
      await tester.pump();

      check(tester.takeException()).isA<AssertionError>();
    });
  });
}

/// Edits [server]'s store and tells the list, as the app would.
typedef _Edit = void Function(FakeServer<_Row> server, ListSmithController<_Row> controller);

/// Picks a fetcher over [FakeServer]'s store.
typedef _FetcherGetter = PageFetcher<_Row> Function(FakeServer<_Row> server);

/// Tall enough that pages 0 to 2 load at mount and page 3 waits for a scroll.
const _rowHeight = 300.0;

/// Short enough that every page loads.
const _shortRowHeight = 20.0;

/// 15 rows named `n02` to `n30` by id, in teams of 5, sorted by name.
List<_Row> _rows() => List.generate(
  15,
  (id) => (id: id, team: 'ABC'[id ~/ 5], name: 'n${((id + 1) * 2).toString().padLeft(2, '0')}'),
);

int _byName(_Row a, _Row b) {
  final order = a.name.compareTo(b.name);

  return order == 0 ? a.id.compareTo(b.id) : order;
}

int _byTeamThenName(_Row a, _Row b) {
  final order = a.team.compareTo(b.team);

  return order == 0 ? _byName(a, b) : order;
}

List<String> _namesOf(FakeServer<_Row> server) =>
    server.store.map((row) => row.name).toList(growable: false);

ScrollController _scrollController() {
  final scrollController = ScrollController();
  addTearDown(scrollController.dispose);

  return scrollController;
}

void _rename(
  FakeServer<_Row> server,
  ListSmithController<_Row> controller,
  int id,
  String name, {
  Comparator<_Row> comparator = _byName,
}) {
  final row = server.store.firstWhere((row) => row.id == id);
  final renamedRow = (id: id, team: row.team, name: name);
  server.store
    ..remove(row)
    ..add(renamedRow)
    ..sort(comparator);
  controller.upsert(renamedRow);
}

void _create(FakeServer<_Row> server, ListSmithController<_Row> controller, _Row row) {
  server.store
    ..add(row)
    ..sort(_byName);
  controller.upsert(row);
}

/// Cursor paging on the last row's name and id.
PageFetcher<_Row> _keysetByName(FakeServer<_Row> server) => PageFetcher.withSignal((request) async {
  final cursor = request.previousSignal as _Row?;
  final page = server.store
      .where((row) => cursor == null || _byName(row, cursor) > 0)
      .take(request.pageSize)
      .toList(growable: false);

  return (page, page.isEmpty ? cursor : page.last);
});

Future<ListSmithController<_Row>> _pumpSorted(
  WidgetTester tester,
  FakeServer<_Row> server,
  ScrollController scrollController, {
  ItemOrder<_Row> order = const SortedBy(_byName),
  PageFetcher<_Row>? fetchPage,
  double rowHeight = _rowHeight,
  PaginationEndPolicy endPolicy = const StopOnEmptyPagesPolicy(),
  Grouping<_Row>? grouping,
  Search<_Row> search = const NoSearch(),
  String query = '',
  ItemBuilder<_Row>? itemBuilder,
}) async {
  final controller = ListSmithController<_Row>();
  await pumpListSmith(
    tester,
    ListSmith<_Row>.async(
      fetchPage: fetchPage ?? server.offsetLateFetcher,
      pageSize: 3,
      itemIdGetter: (row) => row.id,
      order: order,
      endPolicy: endPolicy,
      grouping: grouping,
      search: search,
      query: query,
      searchDebounce: const Duration(milliseconds: 20),
      scroll: ListScrollConfig(controller: scrollController),
      controller: controller,
      itemBuilder:
          itemBuilder ?? (_, row, _) => SizedBox(height: rowHeight, child: Text('row ${row.name}')),
    ),
  );
  await drain(tester, frames: 12);

  return controller;
}

Future<List<String>> _allShownNames(WidgetTester tester, ScrollController scrollController) =>
    allShownTexts(tester, scrollController, 'row ');
