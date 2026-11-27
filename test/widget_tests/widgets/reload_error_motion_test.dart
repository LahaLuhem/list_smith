import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';
import 'package:list_smith/src/widgets/defaults/defaults.dart';

import '../../support/support.dart';

void main() {
  feature('ListSmith.async reload error motion', () {
    final errorFinder = find.byType(NeutralErrorIndicator);

    scenarioOutlineWidgets<({bool isLanding})>(
      'the rows slide as the error comes or goes, never jumping half its height in a frame',
      examples: const {'a pull fails': (isLanding: false), 'a pull lands': (isLanding: true)},
      outline: (tester, example) async {
        final server = FakeServer([1, 2, 3])..failing.add((0, 2));
        final pullHoldCompleter = server.hold(0, attempt: example.isLanding ? 3 : 2);
        await _pumpList(tester, server);
        if (example.isLanding) await pullToRefresh(tester, listScrollableFinder); // its error is up
        final shownErrorHeight = example.isLanding ? tester.getSize(errorFinder).height : null;

        await tester.fling(listScrollableFinder, const Offset(0, 300), 1000);
        for (var frame = 0; frame < 30; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        var lastTop = _topOf(tester, 1);
        var largestStep = 0.0;
        pullHoldCompleter.complete();
        for (var frame = 0; frame < 20; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          final top = _topOf(tester, 1);
          largestStep = math.max(largestStep, (top - lastTop).abs());
          lastTop = top;
        }

        check(largestStep).isLessThan((shownErrorHeight ?? tester.getSize(errorFinder).height) / 2);
      },
    );

    scenarioWidgets('under reduced motion, the error comes and goes at once', (tester) async {
      final server = FakeServer([1, 2, 3])..failing.add((0, 2));
      final controller = ListSmithController<int>();
      await pumpListSmith(
        tester,
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: ListSmith.async(
            fetchPage: server.offsetLateFetcher,
            itemIdGetter: (item) => item,
            refresh: const NoRefresh(),
            controller: controller,
            itemBuilder: (_, item, _) => Text('item $item'),
          ),
        ),
      );
      await drain(tester);
      final startTop = _topOf(tester, 1);

      await controller.refresh();
      await tester.pump();
      check(_topOf(tester, 1)).equals(startTop + tester.getSize(errorFinder).height);

      await controller.refresh();
      await tester.pump();
      check(_topOf(tester, 1)).equals(startTop);
    });

    scenarioWidgets('scrolled away and back, the error does not grow again', (tester) async {
      final server = FakeServer(List.generate(80, (index) => index))..failing.add((0, 2));
      final scrollController = ScrollController();
      await pumpListSmith(
        tester,
        ListSmith.async(
          fetchPage: server.offsetLateFetcher,
          itemIdGetter: (item) => item,
          pageSize: 80,
          scroll: ListScrollConfig(controller: scrollController),
          itemBuilder: (_, item, _) => SizedBox(height: 50, child: Text('item $item')),
        ),
      );
      await drain(tester);
      await pullToRefresh(tester, listScrollableFinder);
      final grownTop = _topOf(tester, 0);

      scrollController.jumpTo(3000); // past the cache extent, so the error's cell goes
      await tester.pump();
      scrollController.jumpTo(0);
      await tester.pump();

      check(_topOf(tester, 0)).equals(grownTop);
    });
  });
}

double _topOf(WidgetTester tester, int item) => tester.getTopLeft(find.text('item $item')).dy;

/// [server]'s rows under the default pull.
Future<void> _pumpList(WidgetTester tester, FakeServer<int> server) async {
  await pumpListSmith(
    tester,
    ListSmith.async(
      fetchPage: server.offsetLateFetcher,
      itemIdGetter: (item) => item,
      itemBuilder: (_, item, _) => Text('item $item'),
    ),
  );
  await drain(tester);
}
