import 'package:flutter/widgets.dart';

import '../../utils/neutral_theme.dart';

/// The neutral default surface shown when the source yields no items at all.
///
/// A centred, muted message on an otherwise empty viewport. Imposes no design system;
/// consumers override the empty builder to customise it.
class NeutralEmptyIndicator extends StatelessWidget {
  /// Creates the neutral empty-state surface.
  const NeutralEmptyIndicator({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Text('No items', style: TextStyle(color: neutralForegroundOf(context))),
  );
}
