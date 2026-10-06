import 'package:checks/checks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith/list_smith.dart';

import '../../../support/support.dart';

void main() {
  feature('The neutral error indicator', () {
    scenarioWidgets('the neutral 1st-page error taller than the list still scrolls to its Retry', (
      tester,
    ) async {
      await pumpListSmith(
        tester,
        MediaQuery(
          data: const MediaQueryData(textScaler: .linear(3)),
          child: Align(
            alignment: .topCenter,
            child: SizedBox(
              height: 200, // the error outgrows it at 3x
              child: ListSmith.async(
                fetchPage: PageFetcher((_) async => throw Exception('down')),
                itemIdGetter: (item) => item,
                itemBuilder: (_, item, _) => Text('item $item'),
              ),
            ),
          ),
        ),
      );
      await drain(tester);

      await tester.drag(find.text('Something went wrong'), const Offset(0, -300));
      await drain(tester);

      check(find.text('Retry').hitTestable().evaluate()).length.equals(1);
    });
  });
}
