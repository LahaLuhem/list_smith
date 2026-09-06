import 'package:flutter/widgets.dart';

import '/src/utils/neutral_theme.dart';

/// The neutral default footer shown once every page has loaded.
///
/// A centred, muted "no more items" line in a padded footer below the list. Override
/// `noMoreItemsBuilder` to replace it.
class NeutralNoMoreItemsIndicator extends StatelessWidget {
  static const double _padding = 16;

  /// Creates the neutral end-of-list footer.
  const new({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const .all(_padding),
    child: Center(
      child: Text('No more items', style: TextStyle(color: neutralForegroundOf(context))),
    ),
  );
}
