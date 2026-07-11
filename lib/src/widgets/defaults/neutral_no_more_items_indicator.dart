import 'package:flutter/widgets.dart';

import '/src/utils/neutral_theme.dart';

/// The neutral default footer shown once every page has loaded.
///
/// A centred, muted "no more items" line in a padded footer below the list.
/// Imposes no design system; consumers override the no-more builder to change it.
class NeutralNoMoreItemsIndicator extends StatelessWidget {
  static const double _padding = 16;

  /// Creates the neutral end-of-list footer.
  const NeutralNoMoreItemsIndicator({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const .all(_padding),
    child: Center(
      child: Text('No more items', style: TextStyle(color: neutralForegroundOf(context))),
    ),
  );
}
