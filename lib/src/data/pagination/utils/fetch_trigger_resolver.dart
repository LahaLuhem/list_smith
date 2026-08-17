import '../enums/fetch_trigger.dart';

/// The [FetchTrigger] for a fetch of [pageIndex]: [pending] when a reset latched one, else derived.
///
/// A reset has to latch, because the re-fetch it causes arrives later from the view, not from itself.
FetchTrigger resolveTrigger({
  required int pageIndex,
  required FetchTrigger? pending,
  required int? lastFailedPageIndex,
}) {
  if (pending != null) return pending;
  if (pageIndex == lastFailedPageIndex) return .retry;

  return pageIndex == 0 ? .initialLoad : .nextPage;
}
