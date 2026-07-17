// perf_driver is a flutter_driver driver (run via `flutter drive`), not a `flutter test` file, so it
// does not follow the `_test.dart` naming convention.
// ignore_for_file: prefer-correct-test-file-name

import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

/// Driver for the UI benchmark scenarios: writes the records the scenario accumulated in
/// `binding.reportData` to the `--dart-define=OUTPUT` path, as a JSON array matching the schema in
/// `harness/result_writer.dart`. Run via
/// `flutter drive --driver=test_driver/perf_driver.dart --target=integration_test/<scenario>.dart`.
Future<void> main() => integrationDriver(
  // A healthy scenario settles in under a minute. Cap the driver wait well below
  // the 20-min default so a wedged device (no frames produced, as in issue #5)
  // fails fast instead of stalling for ~30 min.
  timeout: const Duration(minutes: 5),
  responseDataCallback: (data) async {
    if (data == null) return;

    final outputPath = data['output_path'] as String?;
    final records = data['records'];
    if (outputPath == null || outputPath.isEmpty || records == null) return;

    final file = File(outputPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(records));
  },
);
