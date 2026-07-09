import 'package:flutter/widgets.dart';

import 'neutral_progress_indicator.dart';

/// The neutral default surface shown while a page is loading.
///
/// Wraps [NeutralProgressIndicator] with the layout each slot wants: a centred, larger spinner for
/// the first page (which owns the whole viewport), and a smaller, padded footer spinner for later
/// pages (which sit below the items already loaded). Pass [compact] for the footer form.
class NeutralLoadingIndicator extends StatelessWidget {
  static const double _firstPageSize = 32;
  static const double _newPageSize = 20;
  static const double _newPagePadding = 16;

  /// Whether to render the compact footer form (a later page) rather than the full-viewport form (the first page).
  final bool compact;

  /// Creates the neutral loading surface; pass `compact: true` for the new-page footer form.
  const NeutralLoadingIndicator({this.compact = false, super.key});

  @override
  Widget build(BuildContext context) => compact
      ? const Padding(
          padding: .all(_newPagePadding),
          child: Center(child: NeutralProgressIndicator(size: _newPageSize)),
        )
      : const Center(child: NeutralProgressIndicator(size: _firstPageSize));
}
