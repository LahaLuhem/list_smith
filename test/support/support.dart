/// One-stop widget-test support: the local Gherkin vocabulary (feature / scenarioWidgets /
/// scenarioOutlineWidgets), the pump/drain harness, reusable fake sources, and the recording observer
/// double. Import this single file from a widget test instead of the individual pieces.
library;

export 'bdd.dart';
export 'fake_sources.dart';
export 'list_smith_harness.dart';
export 'recording_list_smith_observer.dart';
