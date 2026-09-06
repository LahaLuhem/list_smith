import 'package:flutter/widgets.dart';

/// Builds the surface shown when a search matches nothing, carrying the `query` that found none.
///
/// Not the empty state: empty means the source holds no items at all, no-results means it holds
/// items and none match.
typedef NoResultsBuilder = Widget Function(BuildContext context, String query);
