import 'dart:convert';
import 'dart:io';

/// Appends self-describing benchmark records to a JSON-array output file.
///
/// One object per iteration, matching the schema in [`benchmark/README.md`](../README.md). One writer
/// per invocation: [open], one [writeRecord] per iteration, then [close].
final class ResultWriter {
  final String _scenario;
  final String _sdkVersion;
  final String _packageVersion;
  final String _gitSha;
  final IOSink _sink;
  var _firstRecord = true;

  new _(this._scenario, this._sdkVersion, this._packageVersion, this._gitSha, this._sink);

  /// Opens [outputPath] and emits the JSON-array prefix `[`. Creates the parent directory if needed.
  static Future<ResultWriter> open({
    required String outputPath,
    required String scenario,
    required String sdkVersion,
    required String packageVersion,
    required String gitSha,
  }) async {
    final file = File(outputPath);
    await file.parent.create(recursive: true);
    // Closed by [close]. The analyzer can't follow the ownership hand-off across the factory.
    // ignore: close_sinks
    final sink = file.openWrite()..write('[\n');

    return ResultWriter._(scenario, sdkVersion, packageVersion, gitSha, sink);
  }

  /// Appends one record for iteration [iteration].
  ///
  /// [samples] holds per-metric arrays of raw measurements, which the analyzer prefers for significance
  /// testing. [summary] holds per-metric scalars the benchmark pre-computed.
  void writeRecord({
    required int iteration,
    required Map<String, List<num>> samples,
    required Map<String, num> summary,
  }) {
    final record = <String, Object?>{
      'scenario': _scenario,
      'iteration': iteration,
      'sdk_version': _sdkVersion,
      'package_version': _packageVersion,
      'git_sha': _gitSha,
      'started_at': DateTime.now().toUtc().toIso8601String(),
      'samples': samples,
      'summary': summary,
    };

    if (!_firstRecord) _sink.write(',\n');
    _sink.write(const JsonEncoder.withIndent('  ').convert(record));
    _firstRecord = false;
  }

  /// Writes the closing `]`, flushes and closes the sink.
  Future<void> close() async {
    _sink.write('\n]\n');

    await _sink.flush();
    await _sink.close();
  }
}
