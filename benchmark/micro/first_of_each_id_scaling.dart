/// Micro-benchmark: [firstOfEachId] cost as the in-memory list grows.
///
/// `.sync` runs it each time the app passes new items, so a slower pass trips the gate. Measured with
/// every id unique, the common case, where nothing goes and every item is copied.
library;

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:list_smith/src/data/presentation/utils/first_of_each_id.dart';

import '../harness/measure.dart';
import '../harness/result_writer.dart';
import '../harness/scenario_arguments.dart';

/// In-memory list sizes the pass is measured against. The pivot for the scaling curve.
const _listSizes = <int>[1000, 10000, 100000];

final class _FirstOfEachIdScaling(final int listSize) extends BenchmarkBase {
  this : super('first_of_each_id_scaling_n$listSize');

  late final List<_Item> _items;
  var lastKeptCount = 0;

  @override
  void setup() => _items = List<_Item>.generate(listSize, _Item.new, growable: false);

  @override
  void run() => lastKeptCount = firstOfEachId(_items, _idOf).items.length;
}

/// A reference-identity item keyed by [id], the shape `itemIdGetter` keys on.
final class const _Item(final int id);

Object _idOf(_Item item) => item.id;

Future<void> main(List<String> arguments) async {
  final scenarioArguments = ScenarioArguments.parse(arguments);

  final writer = await ResultWriter.open(
    outputPath: scenarioArguments.outputPath,
    scenario: 'first_of_each_id_scaling',
    sdkVersion: ScenarioArguments.sdkVersion,
    packageVersion: scenarioArguments.packageVersion,
    gitSha: scenarioArguments.gitSha,
  );

  for (var i = 0; i < scenarioArguments.iterations; i++) {
    for (final listSize in _listSizes) {
      final benchmark = _FirstOfEachIdScaling(listSize);

      final microseconds = measureWindowed(benchmark, millis: scenarioArguments.measureMillis);

      writer.writeRecord(
        iteration: i,
        samples: {
          'microseconds_per_pass': [microseconds],
        },
        summary: {
          'list_size': listSize,
          'microseconds_per_pass': microseconds,
          'kept_count': benchmark.lastKeptCount,
        },
      );
    }
  }

  await writer.close();
}
