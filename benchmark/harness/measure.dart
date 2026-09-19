/// A [BenchmarkBase] measurement whose time window the caller sets.
///
/// `BenchmarkBase.measure` hardcodes 2000ms (`minimumMeasureDurationMillis`), so every pivot costs
/// that much whatever it times. `../README.md#ci-regression-gate` has the per-window evidence.
library;

import 'package:benchmark_harness/benchmark_harness.dart';

/// Discarded settling window, kept short so it can't dominate a sub-second measurement.
const _warmupMillis = 100;

/// Microseconds per operation, timing `exercise` for at least [millis].
///
/// Same phases as `BenchmarkBase.measure`, plus a collection up front so the previous pivot's garbage
/// isn't charged to this one.
double measureWindowed(BenchmarkBase benchmark, {required int millis}) {
  _forceGc();
  benchmark.setup();
  BenchmarkBase.measureFor(benchmark.warmup, _warmupMillis);
  final score = BenchmarkBase.measureFor(benchmark.exercise, millis);
  benchmark.teardown();

  return score;
}

/// Provokes a young-generation collection with a burst of pressure. Imperfect, the VM may defer.
void _forceGc() {
  // ~8 MB of unreachable garbage, kept only for the allocation side effect.
  // ignore: unused_local_variable
  final pressure = List<List<int>>.generate(64, (_) => List<int>.filled(16384, 0));
}
