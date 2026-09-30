import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import 'support/bdd.dart';

void main() {
  feature('Slidable rows under edit transitions', () {
    scenarioWidgets(
      'a full swipe under SlidableAutoCloseBehavior goes at once, with no list exit',
      (tester) async {
        final controller = ListSmithController<int>();
        await tester.pumpWidget(
          Directionality(
            textDirection: .ltr,
            child: MediaQuery(
              data: const MediaQueryData(),
              child: SlidableAutoCloseBehavior(
                child: ListSmith.async(
                  fetchPage: PageFetcher(
                    (request) async => request.pageIndex == 0 ? const [1, 2, 3] : const <int>[],
                  ),
                  itemId: (item) => item,
                  refresh: const NoRefresh(),
                  controller: controller,
                  // Long, so a list exit would still be running when the rows are read.
                  editTransition: EditTransition(
                    duration: const Duration(seconds: 1),
                    transitionBuilder: (child, animation) =>
                        SizeTransition(sizeFactor: animation, child: child),
                  ),
                  itemBuilder: (_, item, _) => Slidable(
                    key: ValueKey(item),
                    groupTag: 'rows',
                    endActionPane: ActionPane(
                      motion: const DrawerMotion(),
                      dismissible: DismissiblePane(onDismissed: () => controller.remove(item)),
                      children: const [
                        Expanded(child: SizedBox.shrink()),
                      ], // the motion wants flexible actions
                    ),
                    child: SizedBox(height: 50, child: Text('item $item')),
                  ),
                ),
              ),
            ),
          ),
        );
        for (var frame = 0; frame < 5; frame++) {
          await tester.pump();
        }

        await tester.timedDrag(
          find.text('item 2'),
          const Offset(-700, 0),
          const Duration(milliseconds: 300),
        );
        // The pane's dismissal, then its shrink, take 300ms each.
        for (var frame = 0; frame < 7; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pump();
        await tester.pump();

        check(tester.takeException()).isNull();
        check(find.text('item 2', skipOffstage: false).evaluate()).isEmpty();
      },
    );
  });
}
