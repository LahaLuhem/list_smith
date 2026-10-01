/// Micro-benchmark: cost of one observer dispatch through list_smith's wrapping.
///
/// list_smith calls `observer?.onPageLoaded(...)` synchronously in `_fetchPage`. This measures a no-op
/// observer's dispatch: the null-check plus one virtual call to an empty override. A `null` observer
/// is cheaper still, so this is the conservative figure.
library;

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:list_smith/src/data/observer/models/list_smith_observer.dart';

import '../harness/measure.dart';
import '../harness/result_writer.dart';
import '../harness/scenario_arguments.dart';

final class _ObserverDispatch(final ListSmithObserver? _observer) extends BenchmarkBase {
  this : super('observer_dispatch');

  @override
  void run() => _observer?.onPageLoaded(0, 20, isSearchMode: false);
}

/// Counts page-load callbacks and does nothing else, mirroring an observer with no expensive side effect
/// on the hot path.
final class _CountingObserver() extends ListSmithObserver {
  var count = 0;

  @override
  void onPageLoaded(int pageIndex, int itemCount, {required bool isSearchMode}) => count++;
}

Future<void> main(List<String> arguments) async {
  final scenarioArguments = ScenarioArguments.parse(arguments);

  final writer = await ResultWriter.open(
    outputPath: scenarioArguments.outputPath,
    scenario: 'observer_dispatch',
    sdkVersion: ScenarioArguments.sdkVersion,
    packageVersion: scenarioArguments.packageVersion,
    gitSha: scenarioArguments.gitSha,
  );

  for (var i = 0; i < scenarioArguments.iterations; i++) {
    final observer = _CountingObserver();

    final microseconds = measureWindowed(
      _ObserverDispatch(observer),
      millis: scenarioArguments.measureMillis,
    );

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
