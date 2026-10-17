import 'package:meta/meta.dart';

import '../enums/fetch_trigger.dart';

/// The [FetchTrigger] for a fetch of [pageIndex]: [pending] when a restart passes one, else derived.
@internal
FetchTrigger resolveTrigger({
  required int pageIndex,
  required FetchTrigger? pending,
  required int? lastFailedPageIndex,
  bool isReread = false,
}) {
  if (pending != null) return pending;
  if (pageIndex == lastFailedPageIndex) return .retry;
  if (isReread) return .invalidated;

  return pageIndex == 0 ? .initialLoad : .nextPage;
}
