import 'package:flutter/widgets.dart';

import '/src/utils/neutral_theme.dart';

/// The neutral default surface shown when a search matches none of the source's items.
///
/// A centred, muted "No results" message. The query is deliberately not echoed, to stay overflow-
/// and i18n-safe. Imposes no design system; consumers override the no-results builder to replace it.
class NeutralNoResultsIndicator extends StatelessWidget {
  /// Creates the neutral no-results surface.
  const NeutralNoResultsIndicator({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Text('No results', style: TextStyle(color: neutralForegroundOf(context))),
  );
}
