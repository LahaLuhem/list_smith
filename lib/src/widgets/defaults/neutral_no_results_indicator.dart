import 'package:flutter/widgets.dart';

import '/src/utils/neutral_theme.dart';

/// The neutral surface for a search that matched nothing.
///
/// The query is deliberately not echoed, to stay overflow- and translation-safe. Override `noResultsBuilder`
/// to replace it.
class const NeutralNoResultsIndicator({super.key}) extends StatelessWidget {
  /// Creates it.
  this;

  @override
  Widget build(BuildContext context) => Center(
    child: Text('No results', style: TextStyle(color: neutralForegroundOf(context))),
  );
}
