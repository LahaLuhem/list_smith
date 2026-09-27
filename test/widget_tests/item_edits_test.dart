// A test-local fake server shares the file with the scenarios that drive it.
// ignore_for_file: prefer-match-file-name

import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../support/support.dart';

typedef _Row = ({int id, String label});

void main() {
  feature('ListSmith.async item edits', () {
    scenarioWidgets('an edit while the next page loads keeps both the edit and the paging', (
      tester,
    ) async {
      final server = _Server(_range(0, 8));
      final hold = server.hold(1, attempt: 1);
      final controller = await _pumpList(tester, fetchPage: server.keyset, itemId: _byValue);
      await drain(tester);

      controller.remove(0);
      await tester.pump();
      await _release(tester, [hold]);

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
        final server = _Server<_Row>([(id: 1, label: 'a'), (id: 2, label: 'b')]);
        final controller = await _pumpList<_Row>(
          tester,
          fetchPage: server.offsetEarly,
          itemId: _byRowId,
          label: _rowLabel,
          endPolicy: const FixedPageCountPolicy(pageCount: 1),
          refresh: const PullToRefresh(reload: ReloadToCurrentDepth()),
        );
        await drain(tester);
        final hold = server.hold(0, attempt: 2);

        unawaited(controller.refresh());
        await drain(tester);
        final beforeEdit = _shownRows();
        edit(controller);
        await tester.pump();
        final afterEdit = _shownRows();
        check(afterEdit).not((it) => it.deepEquals(beforeEdit));
        await _release(tester, [hold]);

        check(server.attempts[0]).equals(2); // the reload did commit
        check(_shownRows()).deepEquals(afterEdit);
      },
    );

    scenarioOutlineWidgets<bool>(
      'a page whose re-fetch fails keeps the edit',
      examples: const {'made before the reload': true, 'made while it runs': false},
      outline: (tester, isBefore) async {
        final server = _Server(_range(0, 5));
        final controller = await _pumpList(
          tester,
          fetchPage: server.offsetEarly,
          itemId: _byValue,
          endPolicy: const FixedPageCountPolicy(pageCount: 2),
          refresh: const PullToRefresh(reload: ReloadToCurrentDepth()),
        );
        await drain(tester, frames: 12);
        final hold = server.hold(0, attempt: 2);
        server.failing.add((0, 2));

        if (isBefore) controller.remove(1);
        unawaited(controller.refresh());
        await drain(tester);
        if (!isBefore) controller.remove(1);
        await tester.pump();
        await _release(tester, [hold]);

        check(server.attempts[1]).equals(2); // the page after it did reload
        check(_shownRows()).deepEquals(_rows([0, 2, 3, 4, 5]));
      },
    );

    scenarioOutlineWidgets<({PaginationEndPolicy policy, List<int> removed})>(
      'the end policy still counts what the server sent after items are removed',
      examples: {
        'StopOnEmptyPagesPolicy, the last page emptied': (
          policy: const StopOnEmptyPagesPolicy(),
          removed: _range(5, 9),
        ),
        'a short-last-page policy, one item removed': (
          policy: const _ShortLastPagePolicy(),
          removed: const [7],
        ),
      },
      outline: (tester, example) async {
        final server = _Server(_range(0, 14));
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        final controller = await _pumpList(
          tester,
          fetchPage: server.keyset,
          itemId: _byValue,
          pageSize: 5,
          rowHeight: 300, // tall enough that page 2 waits for a scroll
          endPolicy: example.policy,
          scrollController: scroll,
        );
        await drain(tester, frames: 12);
        check(server.asked(2)).isFalse();

        for (final id in example.removed) {
          server.store.remove(id);
          controller.remove(id);
        }
        for (var pass = 0; pass < 4; pass++) {
          await drain(tester, frames: 6);
          scroll.jumpTo(scroll.position.maxScrollExtent);
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
        final server = _Server(_range(0, 39));
        final controller = await _pumpList(
          tester,
          fetchPage: server.keyset,
          itemId: _byValue,
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
        itemId: _byValue,
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
        itemId: _byValue,
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
      final server = _Server(_range(1, 6));
      final feedCatchUp = server.hold(0, attempt: 2);
      final controller = ListSmithController<int>();
      await _pumpKept(tester, controller, query: '', feed: server.offsetLate);
      await drain(tester);
      await _pumpKept(tester, controller, query: 'q', feed: server.offsetLate);
      await settle(tester);

      server.store.remove(4);
      controller.remove(4);
      await controller.refresh(); // the kept feed owes a re-read for this
      await drain(tester, frames: 12);
      await _pumpKept(tester, controller, query: '', feed: server.offsetLate);
      await settle(tester);

      check(server.attempts[0]).equals(2); // the feed's re-read is still in flight
      check(_shownRows()).deepEquals(_rows([1, 2, 3, 5, 6]));
      await _release(tester, [feedCatchUp]);
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
        final server = _Server<_Row>([(id: 1, label: 'a'), (id: 2, label: 'b')]);
        final controller = await _pumpList<_Row>(
          tester,
          fetchPage: server.offsetLate,
          itemId: _byRowId,
          label: _rowLabel,
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

    scenarioWidgets('editing a list with no itemId asserts', (tester) async {
      final controller = await _pumpList(
        tester,
        fetchPage: pagedFetcher(const [
          [1, 2, 3],
        ]),
        itemId: null,
        endPolicy: const FixedPageCountPolicy(pageCount: 1),
      );
      await drain(tester);

      check(() => controller.remove(1)).throws<AssertionError>();
      check(() => controller.upsert(4)).throws<AssertionError>();
    });
  });
}

Future<ListSmithController<T>> _pumpList<T extends Object>(
  WidgetTester tester, {
  required PageFetcher<T> fetchPage,
  required ItemId<T>? itemId,
  ListSmithController<T>? controller,
  String Function(T item)? label,
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
      itemId: itemId,
      grouping: grouping,
      search: search,
      query: query,
      searchDebounce: const Duration(milliseconds: 20),
      scroll: ListScrollConfig(controller: scrollController),
      controller: handle,
      itemBuilder:
          itemBuilder ??
          (_, item, _) =>
              SizedBox(height: rowHeight, child: Text('item ${label?.call(item) ?? item}')),
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
  itemId: _byValue,
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

Future<void> _release(WidgetTester tester, Iterable<Completer<void>> holds) async {
  for (final hold in holds) {
    hold.complete();
  }
  await tester.idle();
  await drain(tester, frames: 12);
}

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

/// A store behind the fetchers, with holds and failures keyed by page and attempt.
final class _Server<T extends Object> {
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

extension on _Server<int> {
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

final class _ShortLastPagePolicy extends PaginationEndPolicy {
  const new();

  @override
  bool hasReachedEnd(EndContext context) =>
      context.pageCount > 0 && context.lastPageItemCount < context.pageSize;
}
