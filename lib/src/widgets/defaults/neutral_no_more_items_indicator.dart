import 'package:flutter/widgets.dart';

import '/src/utils/neutral_theme.dart';

/// The neutral footer for a fully-loaded list. Override `noMoreItemsBuilder` to replace it.
class NeutralNoMoreItemsIndicator extends StatelessWidget {
  static const double _padding = 16;

  /// Creates it.
  const new({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const .all(_padding),
    child: Center(
      child: Text('No more items', style: TextStyle(color: neutralForegroundOf(context))),
    ),
  );
}
