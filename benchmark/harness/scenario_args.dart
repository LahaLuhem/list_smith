/// Parsed CLI arguments for a benchmark entrypoint.
///
/// One flag set across every entrypoint, so the Python orchestrator drives them all the same way.
/// [ScenarioArgs.parse] is the list. Hand-parsed: the surface is too small for `package:args`.
library;

import 'dart:io';

final class ScenarioArgs {
  /// Iterations to run in this one subprocess, so process startup amortises over N runs.
  final int iterations;

  final String outputPath;
  final String gitSha;
  final String packageVersion;

  /// Milliseconds each `measure` call times for. Required, so it cannot drift from the orchestrator.
  final int measureMillis;

  const new _({
    required this.iterations,
    required this.outputPath,
    required this.gitSha,
    required this.packageVersion,
    required this.measureMillis,
  });

  /// Parses the standard flags from [argv], exiting non-zero on failure. Benchmarks are non-interactive,
  /// so a thrown exception would have no handler.
  factory parse(List<String> argv) {
    final flags = <String, String>{};
    for (var i = 0; i < argv.length; i++) {
      final arg = argv[i];
      if (!arg.startsWith('--')) _die('unexpected positional arg: $arg');
      if (i + 1 >= argv.length) _die('flag $arg missing value');
      flags[arg.replaceFirst('--', '')] = argv[++i];
    }

    final iterations = _requiredInt(flags, 'iterations');
    if (iterations <= 0) _die('--iterations must be >= 1, got: $iterations');
    final outputPath = _required(flags, 'output');
    final gitSha = _required(flags, 'git-sha');
    final packageVersion = _required(flags, 'package-version');
    final measureMillis = _requiredInt(flags, 'measure-millis');
    if (measureMillis <= 0) _die('--measure-millis must be >= 1, got: $measureMillis');

    return ScenarioArgs._(
      iterations: iterations,
      outputPath: outputPath,
      gitSha: gitSha,
      packageVersion: packageVersion,
      measureMillis: measureMillis,
    );
  }

  /// The Dart SDK version from [Platform.version]. A different SDK invalidates a captured baseline.
  static String get sdkVersion => Platform.version.split(' ').first;

  static String _required(Map<String, String> flags, String name) {
    final value = flags[name];
    if (value == null || value.isEmpty) _die('missing required flag: --$name');

    return value;
  }

  static int _requiredInt(Map<String, String> flags, String name) {
    final raw = _required(flags, name);
    final parsed = int.tryParse(raw);
    if (parsed == null) _die('flag --$name expects an int, got: $raw');

    return parsed;
  }

  static Never _die(String message) {
    stderr.writeln('scenario_args: $message');
    exit(64); // EX_USAGE
  }
}
