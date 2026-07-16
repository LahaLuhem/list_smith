/// Micro-benchmark: [bucketByGroup] cost as the in-memory list grows.
///
/// The sync grouping path reorders its (filtered) items into contiguous sections via `bucketByGroup`
/// (a `groupListsBy` + flatten) synchronously on every committed query, before rendering. Measuring
/// it AOT across a range of list sizes puts a trustworthy microseconds figure on where a big grouped
/// list crosses the frame budget. The key extractor is a cheap modulo into a fixed number of groups,
/// over fully interleaved input, so it exercises the real bucketing (every item reordered).
library;

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:list_smith/src/data/grouping/utils/grouping_resolver.dart';

import '../harness/result_writer.dart';
import '../harness/scenario_args.dart';

/// In-memory list sizes the resolver is measured against; the pivot for the scaling curve.
const _listSizes = <int>[1000, 10000, 100000];

/// The number of groups the key buckets into; a realistic small section count.
const _groupCount = 8;

final class _BucketByGroupScaling extends BenchmarkBase {
  _BucketByGroupScaling(this.listSize) : super('bucket_by_group_scaling_n$listSize');

  final int listSize;
  late final List<int> _items;
  var lastBucketedCount = 0;

  @override
  void setup() => _items = List<int>.generate(listSize, (i) => i, growable: false);

  @override
  void run() {
    final bucketed = bucketByGroup(_items, _groupKey);
    lastBucketedCount = bucketed.length;
  }

  static Object _groupKey(int item) => item % _groupCount;
}

Future<void> main(List<String> argv) async {
  final args = ScenarioArgs.parse(argv);

  final writer = await ResultWriter.open(
    outputPath: args.outputPath,
    scenario: 'bucket_by_group_scaling',
    sdkVersion: ScenarioArgs.sdkVersion,
    packageVersion: args.packageVersion,
    gitSha: args.gitSha,
  );

  for (var i = 0; i < args.iterations; i++) {
    for (final listSize in _listSizes) {
      final benchmark = _BucketByGroupScaling(listSize);

      forceGc();
      final microseconds = benchmark.measure();

      writer.writeRecord(
        iteration: i,
        samples: {
          'microseconds_per_bucket': [microseconds],
        },
        summary: {
          'list_size': listSize,
          'microseconds_per_bucket': microseconds,
          'bucketed_count': benchmark.lastBucketedCount,
        },
      );
    }
  }

  await writer.close();
}
