/// Micro-benchmark: cost of one observer dispatch through list_smith's wrapping.
///
/// list_smith calls `observer?.onPageLoaded(...)` synchronously in `_fetchPage`. This measures a
/// no-op observer's dispatch (the null-check plus one virtual call to an empty override), putting a
/// number on "the observer seam costs ~nothing when the override is cheap" (BICC's `observer_dispatch`
/// analogue). A `null` observer is even cheaper (just the null-check), so this no-op case is the
/// conservative figure.
library;

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:list_smith/src/data/observer/models/list_smith_observer.dart';

import '../harness/result_writer.dart';
import '../harness/scenario_args.dart';

final class _ObserverDispatch extends BenchmarkBase {
  _ObserverDispatch(this._observer) : super('observer_dispatch');

  final ListSmithObserver? _observer;

  @override
  void run() => _observer?.onPageLoaded(0, 20, isSearchMode: false);
}

/// A minimal observer that counts page-load callbacks and does no other work; mirrors a steady-state
/// consumer observer with no expensive side effect on the hot path.
final class _CountingObserver extends ListSmithObserver {
  _CountingObserver();

  var count = 0;

  @override
  void onPageLoaded(int pageIndex, int itemCount, {required bool isSearchMode}) => count++;
}

Future<void> main(List<String> argv) async {
  final args = ScenarioArgs.parse(argv);

  final writer = await ResultWriter.open(
    outputPath: args.outputPath,
    scenario: 'observer_dispatch',
    sdkVersion: ScenarioArgs.sdkVersion,
    packageVersion: args.packageVersion,
    gitSha: args.gitSha,
  );

  for (var i = 0; i < args.iterations; i++) {
    final observer = _CountingObserver();

    forceGc();
    final microseconds = _ObserverDispatch(observer).measure();

    writer.writeRecord(
      iteration: i,
      samples: {
        'microseconds_per_dispatch': [microseconds],
      },
      summary: {'microseconds_per_dispatch': microseconds, 'total_dispatches': observer.count},
    );
  }

  await writer.close();
}
