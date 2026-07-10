import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:list_smith_example/main.dart';

import 'support/bdd.dart';

void main() {
  feature('list_smith example app', () {
    scenarioWidgets('home lists the demos, and the basic feed loads its items', (tester) async {
      await tester.pumpWidget(const ListSmithExampleApp());
      await tester.pump();

      check(find.text('Basic feed').evaluate()).length.equals(1);

      await tester.tap(find.text('Basic feed'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      check(find.text('Item 1').evaluate()).length.equals(1);
    });

    scenarioWidgets('custom surfaces: the custom loader shows, then items load', (tester) async {
      await tester.pumpWidget(const ListSmithExampleApp());
      await tester.pump();

      await tester.tap(find.text('Custom surfaces'));
      // Drive the route transition, then assert the custom first-page loader is
      // up before the fake fetch resolves; the spinner animates forever so we
      // never pumpAndSettle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      check(find.text('Loading…').evaluate()).length.equals(1);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      check(find.text('Item 1').evaluate()).length.equals(1);
    });

    scenarioWidgets('playground loads its gappy source', (tester) async {
      await tester.pumpWidget(const ListSmithExampleApp());
      await tester.pump();

      await tester.tap(find.text('Playground'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      check(find.text('Item 1').evaluate()).length.equals(1);
    });
  });
}
