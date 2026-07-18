/// Scenario: a slow synchronous observer delays list_smith rendering its own first page.
///
/// The headline UI choke point (mirrors `better_internet_connectivity_checker`'s `slow_observer`).
/// list_smith fires `onPageLoaded` *synchronously inside `_fetchPage`, before handing the page to
/// ISP*, so a slow observer delays the list appearing, not just the consumer's side effect. This
/// measures render latency: wall-clock from "the page's data is ready" to "the first item is in the
/// widget tree", with a [SlowListSmithObserver] attached.
///
/// Runs under a live `integration_test` binding (real frames, real clock) in profile mode, so the
/// `sleep()` genuinely blocks the UI isolate and the [Stopwatch] measures real time. Metrics are
/// directional for absolute UI cost but faithful here, since the observer's own `sleep` dominates.
///
/// Sweeps a range of observer delays (one record per delay) so the report can show render latency
/// tracking the delay ~1:1: each added millisecond of synchronous observer work adds ~1 ms of render
/// latency, on top of a fixed baseline render. `delay = 0` is that baseline (a near-no-op observer).
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:list_smith/list_smith.dart';

import 'support/host_frame.dart';
import 'support/slow_list_smith_observer.dart';

const _iterations = int.fromEnvironment('ITERATIONS', defaultValue: 10);
const _pageSize = int.fromEnvironment('PAGE_SIZE', defaultValue: 20);
const _outputPath = String.fromEnvironment('OUTPUT');
const _gitSha = String.fromEnvironment('GIT_SHA', defaultValue: 'unknown');
const _packageVersion = String.fromEnvironment('PKG_VERSION', defaultValue: 'unknown');

// Observer delays swept per run; 0 is the no-observer-work baseline (the y-intercept of the line).
const _observerDelaysMillis = <int>[0, 25, 50, 100];

// Bound on the pump loop waiting for the first item, so a stalled fetch can't hang the run.
const _maxPumpsPerIteration = 2000;

// Item height chosen so one page overflows the 800px viewport: ISP then does not eagerly prefetch a
// second page, so the render-latency window isolates a single (slow) observer callback.
const _itemExtentPixels = 100.0;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a slow synchronous observer delays list_smith rendering its first page', (
    tester,
  ) async {
    final records = <Map<String, dynamic>>[];

    for (final delayMillis in _observerDelaysMillis) {
      final renderLatencyMicros = <int>[];
      var totalPageLoads = 0;

      for (var i = 0; i < _iterations; i++) {
        final stopwatch = Stopwatch()..start();
        int? dataReadyMicros;

        Future<List<int>> fetchPage(int pageIndex, int pageSize) async {
          // Stamp when the page's data is ready, BEFORE list_smith fires the (slow) observer.
          dataReadyMicros ??= stopwatch.elapsedMicroseconds;

          return List<int>.generate(pageSize, (index) => pageIndex * pageSize + index);
        }

        final observer = SlowListSmithObserver(delay: Duration(milliseconds: delayMillis));

        await tester.pumpWidget(
          HostFrame(
            key: ValueKey('${delayMillis}_$i'),
            child: ListSmith<int>.async(
              fetchPage: PageFetcher(fetchPage),
              pageSize: _pageSize,
              refresh: const NoRefresh(),
              observer: observer,
              itemBuilder: (_, item, _) => SizedBox(
                height: _itemExtentPixels,
                child: Text('item $item', key: ValueKey('item_$item')),
              ),
            ),
          ),
        );

        final firstItem = find.byKey(const ValueKey('item_0'));
        var pumps = 0;
        while (firstItem.evaluate().isEmpty && pumps < _maxPumpsPerIteration) {
          await tester.pump(const Duration(milliseconds: 8));
          pumps++;
        }

        final renderedMicros = stopwatch.elapsedMicroseconds;
        renderLatencyMicros.add(renderedMicros - (dataReadyMicros ?? renderedMicros));

        totalPageLoads += observer.callCounts['onPageLoaded'] ?? 0;
      }

      records.add(_buildRecord(delayMillis, renderLatencyMicros, totalPageLoads));
    }

    binding.reportData = <String, dynamic>{'output_path': _outputPath, 'records': records};
  });
}

Map<String, dynamic> _buildRecord(int delayMillis, List<int> latencies, int totalPageLoads) {
  final sorted = [...latencies]..sort();
  final median = sorted.isEmpty ? 0 : sorted[sorted.length ~/ 2];

  return <String, dynamic>{
    'scenario': 'slow_observer',
    'iteration': 0,
    'sdk_version': Platform.version.split(' ').first,
    'package_version': _packageVersion,
    'git_sha': _gitSha,
    'started_at': DateTime.now().toUtc().toIso8601String(),
    'samples': <String, List<num>>{'render_latency_micros': latencies},
    'summary': <String, num>{
      'median_render_latency_micros': median,
      'observer_delay_millis': delayMillis,
      'iterations': latencies.length,
      'total_page_loads': totalPageLoads,
    },
  };
}
