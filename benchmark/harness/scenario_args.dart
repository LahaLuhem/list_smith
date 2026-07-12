/// Parsed CLI arguments for a benchmark micro (or pure-Dart scenario) entrypoint. Ported from the
/// `better_internet_connectivity_checker` suite.
///
/// Every entrypoint accepts a small standard flag set so the Python orchestrator can drive them
/// uniformly: `--iterations N`, `--output PATH`, `--git-sha SHA`, `--package-version V`, and optional
/// `--duration-seconds N` (micros ignore duration). Hand-parsed: the surface is too small to justify
/// a `package:args` dependency.
library;

import 'dart:io';

/// The standard flag set every benchmark entrypoint parses from its argv.
final class ScenarioArgs {
  /// How many iterations to run in this one subprocess invocation; the entrypoint loops `0..N-1` and
  /// emits one record per iteration, amortising process startup over N runs.
  final int iterations;

  /// Path the JSON result file is written to.
  final String outputPath;

  /// The git HEAD SHA captured by the orchestrator, recorded in every record for traceability.
  final String gitSha;

  /// The package version captured by the orchestrator from `pubspec.yaml`, recorded in every record.
  final String packageVersion;

  /// Wall-clock seconds a long-running scenario should run; micro-benchmarks ignore this.
  final int durationSeconds;

  const ScenarioArgs._({
    required this.iterations,
    required this.outputPath,
    required this.gitSha,
    required this.packageVersion,
    required this.durationSeconds,
  });

  /// Parses the standard flags from [argv], exiting with a non-zero code on failure (benchmarks are
  /// non-interactive, so a thrown exception would have no handler).
  factory ScenarioArgs.parse(List<String> argv) {
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
    final durationSeconds = int.tryParse(flags['duration-seconds'] ?? '10') ?? 10;

    return ScenarioArgs._(
      iterations: iterations,
      outputPath: outputPath,
      gitSha: gitSha,
      packageVersion: packageVersion,
      durationSeconds: durationSeconds,
    );
  }

  /// The Dart SDK version from [Platform.version]; a different SDK invalidates a captured baseline.
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
