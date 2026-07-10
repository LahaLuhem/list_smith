/// A thin, local Gherkin vocabulary over `flutter_test`, mirroring the `minted`
/// package's `test/support/bdd.dart` but for widget tests.
///
/// `bdd_framework` can't drive widget tests (it wraps `test`, with no
/// `WidgetTester`), so widget scenarios use this instead: [feature] and
/// [scenarioWidgets] make the widget under test and its expected behaviour read
/// as a specification, and [scenarioOutlineWidgets] drives one widget from a
/// table of named examples, so the input values stay grouped as clear
/// parameters instead of scattered through the test body.
library;

import 'package:flutter_test/flutter_test.dart';

/// Groups the widget scenarios describing one widget under test. Reads as
/// `Feature: <description>` in the test output.
void feature(String description, void Function() body) => group('Feature: $description', body);

/// One widget behaviour, as a single `testWidgets` case. Reads as
/// `Scenario: <description>`; [body] is the Given/When/Then flow.
void scenarioWidgets(String description, WidgetTesterCallback body) =>
    testWidgets('Scenario: $description', body);

/// A widget scenario exercised once per row of an examples table.
///
/// [examples] maps each row's name (what makes the case interesting) to its
/// data. [outline] receives the [WidgetTester] and each row, and becomes one
/// `testWidgets` case per row, so a failure names the row that broke.
void scenarioOutlineWidgets<Row>(
  String description, {
  required Map<String, Row> examples,
  required Future<void> Function(WidgetTester tester, Row example) outline,
}) => group('Scenario Outline: $description', () {
  for (final MapEntry(key: name, value: row) in examples.entries) {
    testWidgets(name, (tester) => outline(tester, row));
  }
});
