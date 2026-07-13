# Benchmark results

Captured **2026-07-12** against `0.0.0` at `b2272b8` on Dart SDK 3.12.2. N=10 iterations.

> Per-machine measurements. Numbers reflect *this* machine (CPU, GPU, GC, OS scheduler, thermal state). Your numbers WILL differ; capture your own local baseline before measuring a code delta.

## Observer on the critical path: a slow observer blocks rendering

The headline finding. `slow_observer` (profile-mode) wires an observer that blocks for `observer_delay_millis` on each callback and measures render latency over a page load. list_smith invokes the observer *synchronously* on the page-load path, so the block lands almost fully on the critical path: a 50 ms observer pushes render latency to ~68 ms (an ~18 ms baseline render plus the observer's whole 50 ms). Takeaway for consumers: keep observer callbacks cheap (logging, metrics); push heavy work off the synchronous path.

| Observer delay (ms) | Median render latency (ms) | Render minus observer (ms) | N |
|---:|---:|---:|---:|
| 50 | 68.5 | 18.5 | 10 |

## Sync-search filter cost vs list size

From the `sync_search_scaling` micro (AOT, `benchmark_harness`). `SyncListView` re-runs `resolveSyncSearch` (an `items.where(predicate).toList()`) synchronously on every committed query; this measures that cost as the in-memory list grows, with a naive case-insensitive `contains` predicate. Where the median crosses the frame budget is the practical ceiling for sync search with this predicate.

| List size | N | Median (us) | IQR (us) | Median (ms) |
|---:|---:|---:|---:|---:|
| 1,000 | 10 | 383.72 | 1.29 | 0.38 |
| 10,000 | 10 | 4,028 | 25.24 | 4.03 |
| 100,000 | 10 | 42,092 | 95.81 | 42.09 |


![Sync-search scaling](sync_search_scaling.png)

## Wrapping overhead: list_smith on top of ISP

Confirms the wrapping costs ~nothing. `observer_dispatch` is one no-op observer callback (the null-check + virtual call list_smith makes in `_fetchPage`); `wrapping_overhead` is the per-`getNextPageKey` cost (rebuild the page-item-counts + run the end policy) as loaded pages grow. Both are dwarfed by any real fetch.

| Micro | Metric | Median (us) |
|---|---|---:|
| `observer_dispatch` | us / dispatch | 0.011 |
| `wrapping_overhead` (1 page) | us / key | 0.522 |
| `wrapping_overhead` (10 pages) | us / key | 1.27 |
| `wrapping_overhead` (100 pages) | us / key | 8.21 |

## UI scroll/refresh: per-frame build cost

From the profile-mode `integration_test` scenarios (real frames on this machine). `avg`/`worst`/`p99 build` are the UI-thread build cost per frame (where list_smith's code runs); `missed` counts frames over the 16.67ms budget. `isp_scroll` vs `bare_listview` (same items + scroll, no list_smith) is the attribution: the small delta is what list_smith-over-ISP adds on top of a plain list.

| Scenario | Frames | Avg build (ms) | Worst build (ms) | p99 build (ms) | Missed |
|---|---:|---:|---:|---:|---:|
| `bare_listview` | 610 | 0.50 | 1.80 | 1.53 | 0 |
| `cri_refresh` | 850 | 0.39 | 1.26 | 0.96 | 0 |
| `isp_scroll` | 610 | 0.53 | 1.98 | 1.52 | 0 |
