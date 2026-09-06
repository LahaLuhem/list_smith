import 'package:flutter/widgets.dart';

import 'neutral_progress_indicator.dart';

/// The neutral default surface shown while a page is loading.
///
/// Wraps [NeutralProgressIndicator] in the layout each slot wants: centred and larger for the first
/// page, smaller and padded for a footer below the items already loaded. Pass [compact] for the
/// footer form.
class NeutralLoadingIndicator extends StatelessWidget {
  static const double _firstPageSize = 32;
  static const double _newPageSize = 20;
  static const double _newPagePadding = 16;

  /// Whether to render the compact footer form rather than the full-viewport one.
  final bool compact;

  /// Creates the neutral loading surface.
  const new({this.compact = false, super.key});

  @override
  Widget build(BuildContext context) => compact
      ? const Padding(
          padding: .all(_newPagePadding),
          child: Center(child: NeutralProgressIndicator(size: _newPageSize)),
        )
      : const Center(child: NeutralProgressIndicator(size: _firstPageSize));
}
