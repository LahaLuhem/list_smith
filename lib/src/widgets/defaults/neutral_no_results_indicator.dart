import 'package:flutter/widgets.dart';

import '/src/utils/neutral_theme.dart';

/// The neutral surface for a search that matched nothing.
///
/// The query is deliberately not echoed, to stay overflow- and translation-safe. Override `noResultsBuilder`
/// to replace it.
class NeutralNoResultsIndicator extends StatelessWidget {
  /// Creates it.
  const new({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Text('No results', style: TextStyle(color: neutralForegroundOf(context))),
  );
}
