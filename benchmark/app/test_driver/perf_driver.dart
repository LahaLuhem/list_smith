// A flutter_driver driver, run via `flutter drive`, not a `flutter test` file, so the
// `_test.dart` naming convention doesn't apply.
// ignore_for_file: prefer-correct-test-file-name

import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

/// Driver for the UI benchmark scenarios. Writes whatever the scenario accumulated in
/// `binding.reportData` to the `--dart-define=OUTPUT` path, as a JSON array matching
/// `harness/result_writer.dart`'s schema.
///
/// `flutter drive --driver=test_driver/perf_driver.dart --target=integration_test/<scenario>.dart`
Future<void> main() => integrationDriver(
  // A healthy scenario settles inside a minute, so cap the wait well below the 20-min default. A
  // wedged device producing no frames then fails fast instead of stalling for half an hour.
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
