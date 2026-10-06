import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../../../../support/support.dart';

void main() {
  feature('ListSmith.async pull surfaces', () {
    Widget list(
      FakeServer<int> server, {
      ListScrollConfig scrollConfig = const ListScrollConfig(),
      Refresh refresh = const PullToRefresh(),
    }) => ListSmith.async(
      fetchPage: server.offsetLateFetcher,
      itemIdGetter: (item) => item,
      pageSize: 3,
      endPolicy: const FixedPageCountPolicy(pageCount: 1),
      scroll: scrollConfig,
      refresh: refresh,
      itemBuilder: (_, item, _) => SizedBox.square(dimension: 50, child: Text('item $item')),
    );

    scenarioWidgets('a pull on the loader starts no refresh', (tester) async {
      final server = FakeServer<int>([1, 2, 3]);
      final firstLoadHoldCompleter = server.hold(0, attempt: 1);
      var isIndicatorShown = false;
      await pumpListSmith(
        tester,
        list(
          server,
          refresh: PullToRefresh(
            indicatorBuilder: (_, _) {
              isIndicatorShown = true;

              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await drain(tester);
      // Premise: the loader is up.
      check(find.textContaining('item ').evaluate()).isEmpty();

      await pullToRefresh(tester, find.byType(Scrollable));
      await release(tester, [firstLoadHoldCompleter]);

      check(isIndicatorShown).isFalse();
      check(server.attempts[0]).equals(1);
      // The same pull on the rows refreshes, so the one above did reach the list.
      await pullToRefresh(tester, find.byType(Scrollable));
      check(server.attempts[0]).equals(2);
    });

    scenarioOutlineWidgets<_PullSetup>(
      'a surface that takes a pull takes it whatever the scroll setup',
      examples: {
        'a short list, with a ScrollController': (
          makeServer: () => FakeServer([1, 2, 3]),
          makeScrollConfig: (controller) => ListScrollConfig(controller: controller),
          pullOffset: _pullDownOffset,
        ),
        'a short list, with explicit physics': (
          makeServer: () => FakeServer([1, 2, 3]),
          makeScrollConfig: (_) => const ListScrollConfig(physics: BouncingScrollPhysics()),
          pullOffset: _pullDownOffset,
        ),
        'a short list, horizontal': (
          makeServer: () => FakeServer([1, 2, 3]),
          makeScrollConfig: (_) => const ListScrollConfig(scrollDirection: .horizontal),
          pullOffset: const Offset(300, 0),
        ),
        'the 1st-page error, with a ScrollController': (
          makeServer: () => FakeServer([1, 2, 3])..failing.add((0, 1)),
          makeScrollConfig: (controller) => ListScrollConfig(controller: controller),
          pullOffset: _pullDownOffset,
        ),
        'the 1st-page error, with explicit physics': (
          makeServer: _failingServer,
          makeScrollConfig: (_) => const ListScrollConfig(physics: BouncingScrollPhysics()),
          pullOffset: _pullDownOffset,
        ),
        'the empty list, with a ScrollController': (
          makeServer: () => FakeServer(<int>[]),
          makeScrollConfig: (controller) => ListScrollConfig(controller: controller),
          pullOffset: _pullDownOffset,
        ),
      },
      outline: (tester, setup) async {
        final server = setup.makeServer();
        final scrollController = ScrollController();
        addTearDown(scrollController.dispose);
        await pumpListSmith(
          tester,
          list(server, scrollConfig: setup.makeScrollConfig(scrollController)),
        );
        await drain(tester);

        await pullToRefresh(tester, listScrollableFinder, offset: setup.pullOffset);

        check(server.attempts[0]).equals(2);
      },
    );

    scenarioOutlineWidgets<
      ({
        FakeServer<int> Function() makeServer,
        Set<PullableSurface> pullableSurfaces,
        bool isPulled,
      })
    >(
      'a surface takes a pull only while the pull lists it',
      examples: {
        'the error, listed': (
          makeServer: _failingServer,
          pullableSurfaces: const {.error},
          isPulled: true,
        ),
        'the error, left out': (
          makeServer: _failingServer,
          pullableSurfaces: const {.empty},
          isPulled: false,
        ),
        'the empty list, listed': (
          makeServer: _emptyServer,
          pullableSurfaces: const {.empty},
          isPulled: true,
        ),
        'the empty list, left out': (
          makeServer: _emptyServer,
          pullableSurfaces: const {.error},
          isPulled: false,
        ),
      },
      outline: (tester, example) async {
        final server = example.makeServer();
        await pumpListSmith(
          tester,
          list(server, refresh: PullToRefresh(pullableSurfaces: example.pullableSurfaces)),
        );
        await drain(tester);

        await pullToRefresh(tester, listScrollableFinder);

        check(server.attempts[0]).equals(example.isPulled ? 2 : 1);
      },
    );

    scenarioWidgets("an app's NeverScrollableScrollPhysics keeps the list from taking a pull", (
      tester,
    ) async {
      final server = FakeServer<int>([1, 2, 3]);
      await pumpListSmith(
        tester,
        list(server, scrollConfig: const ListScrollConfig(physics: NeverScrollableScrollPhysics())),
      );
      await drain(tester);

      await pullToRefresh(tester, find.byType(Scrollable));
      check(server.attempts[0]).equals(1);
      // Without it the same pull refreshes, so the one above did reach the list.
      await pumpListSmith(tester, list(server));
      await pullToRefresh(tester, find.byType(Scrollable));
      check(server.attempts[0]).equals(2);
    });
  });
}

/// A list's data and scroll setup, and the drag that pulls it from its start edge.
typedef _PullSetup = ({
  FakeServer<int> Function() makeServer,
  ListScrollConfig Function(ScrollController controller) makeScrollConfig,
  Offset pullOffset,
});

const _pullDownOffset = Offset(0, 300);

FakeServer<int> _failingServer() => FakeServer([1, 2, 3])..failing.add((0, 1));

FakeServer<int> _emptyServer() => FakeServer(<int>[]);
