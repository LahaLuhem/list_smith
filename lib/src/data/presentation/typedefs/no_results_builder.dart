import 'package:flutter/widgets.dart';

/// Builds the surface for a search that matched nothing, carrying the `query` that found none.
///
/// Not the empty state. Empty means the source has no items at all, no-results means it has some and
/// none match.
typedef NoResultsBuilder = Widget Function(BuildContext context, String query);
