import '../enums/fetch_trigger.dart';

/// The [FetchTrigger] for a fetch of [pageIndex]: [pending] when a restart passes one, else derived.
FetchTrigger resolveTrigger({
  required int pageIndex,
  required FetchTrigger? pending,
  required int? lastFailedPageIndex,
}) {
  if (pending != null) return pending;
  if (pageIndex == lastFailedPageIndex) return .retry;

  return pageIndex == 0 ? .initialLoad : .nextPage;
}
