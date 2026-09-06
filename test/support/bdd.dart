/// A thin, local Gherkin vocabulary over `flutter_test`, mirroring `minted`'s but for widget tests.
///
/// `bdd_framework` can't drive them: it wraps `test`, so there is no `WidgetTester`. [feature] and
/// [scenarioWidgets] make the widget and its expected behaviour read as a specification, and
/// [scenarioOutlineWidgets] drives one widget from a table of named examples, so the inputs stay
/// grouped instead of scattered through the body.
///
/// A local helper can't cross a package boundary, so `test/support/bdd.dart` and
/// `example/test/support/bdd.dart` are byte-identical copies. Edit both.
library;

import 'package:flutter_test/flutter_test.dart';

/// Groups the widget scenarios describing one widget under test. Reads as
/// `Feature: <description>` in the test output.
void feature(String description, void Function() body) => group('Feature: $description', body);

/// One widget behaviour, as a single `testWidgets` case. Reads as
/// `Scenario: <description>`, with [body] the Given/When/Then flow.
void scenarioWidgets(String description, WidgetTesterCallback body) =>
    testWidgets('Scenario: $description', body);

/// A widget scenario exercised once per row of an examples table.
///
/// [examples] maps each row's name to its data, and [outline] becomes one `testWidgets` case per
/// row, so a failure names the row that broke.
void scenarioOutlineWidgets<Row>(
  String description, {
  required Map<String, Row> examples,
  required Future<void> Function(WidgetTester tester, Row example) outline,
}) => group('Scenario Outline: $description', () {
  for (final MapEntry(key: name, value: row) in examples.entries) {
    testWidgets(name, (tester) => outline(tester, row));
  }
});
