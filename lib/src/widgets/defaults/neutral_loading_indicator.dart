import 'package:flutter/widgets.dart';

import 'neutral_progress_indicator.dart';

/// The neutral surface shown while a page loads.
///
/// A [NeutralProgressIndicator], centred and larger for the 1st page. Pass [isCompact] for the smaller
/// padded footer form.
class const NeutralLoadingIndicator({
  /// Render the compact footer form rather than the full-viewport one.
  final bool isCompact = false,
  super.key,
}) extends StatelessWidget {
  static const double _firstPageSize = 32;
  static const double _newPageSize = 20;
  static const double _newPagePadding = 16;

  /// Creates it.
  this;

  @override
  Widget build(BuildContext context) => isCompact
      ? const Padding(
          padding: .all(_newPagePadding),
          child: Center(child: NeutralProgressIndicator(size: _newPageSize)),
        )
      : const Center(child: NeutralProgressIndicator(size: _firstPageSize));
}
