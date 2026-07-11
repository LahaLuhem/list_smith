import 'package:flutter/widgets.dart';

/// Builds the surface shown when a search runs but matches nothing, carrying the `query` that found
/// no results (parallel to how `ErrorBuilder` carries its error).
///
/// Distinct from the empty-state builder: empty means the source itself has no items; no-results
/// means the source has items but none match the active query. Shared by the sync and async search
/// paths.
typedef NoResultsBuilder = Widget Function(BuildContext context, String query);
