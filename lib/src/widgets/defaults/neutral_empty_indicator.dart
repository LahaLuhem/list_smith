import 'package:flutter/widgets.dart';

import '/src/utils/neutral_theme.dart';

/// The neutral surface for a source with no items at all. Override `emptyBuilder` to replace it.
class NeutralEmptyIndicator extends StatelessWidget {
  /// Creates it.
  const new({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Text('No items', style: TextStyle(color: neutralForegroundOf(context))),
  );
}
