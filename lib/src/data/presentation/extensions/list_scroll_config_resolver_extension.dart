import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import '../models/list_scroll_config.dart';

/// Converts [ListScrollConfig.cacheExtent] to the shape scroll views take now, their `double` one being
/// deprecated. Its own file, so the conversion stays off the public type.
extension ListScrollConfigResolverExtension on ListScrollConfig {
  /// Null when no cache extent is set.
  ScrollCacheExtent? get scrollCacheExtent {
    final pixels = cacheExtent;

    return pixels == null ? null : ScrollCacheExtent.pixels(pixels);
  }
}
