import 'package:checks/checks.dart';

extension ValueChecks on Subject<Object> {
  /// Its `toString` isn't Dart's default `Instance of '…'`, so a log or a failed check names it.
  void readsAsItself() =>
      has((value) => value.toString(), 'toString').not((it) => it.startsWith("Instance of '"));
}
