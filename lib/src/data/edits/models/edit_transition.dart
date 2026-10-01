/// @docImport '/src/widgets/list_smith.dart';
library;

import 'package:flutter/widgets.dart';

part 'edit_transitions/animated_edit_transition.dart';
part 'edit_transitions/no_edit_transition.dart';

/// Whether the rows edits add and take animate, and how.
///
/// [NoEditTransition] (the default) shows an edit at once. [EditTransition.new] animates the row an
/// `upsert` adds and the row a `remove` takes, and nothing else, so page loads and reloads never do.
/// [ListSmith.async] only, like the edits.
sealed class const EditTransition._() {
  /// [transitionBuilder] wraps the row, run forward for one coming in and in reverse for one going out, so
  /// `AnimatedSwitcher.defaultTransitionBuilder` drops straight in.
  const factory({
    required Duration duration,
    required AnimatedSwitcherTransitionBuilder transitionBuilder,
  }) = AnimatedEditTransition._;
}
