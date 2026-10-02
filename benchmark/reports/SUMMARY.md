# Benchmark results

Captured **2026-10-02** against `1.0.0` at `35b01b5` on Dart SDK 3.13.4. N=10 iterations.

> Per-machine measurements, reflecting *this* machine's CPU, GPU, GC, OS scheduler and thermal state. Yours WILL differ, so capture your own baseline before measuring a delta.

## Observer on the critical path: a slow observer blocks rendering

The headline finding. list_smith invokes your observer *synchronously* on the page-load path, so a slow callback lands almost fully on the critical path. `slow_observer` blocks for a set delay on each callback and measures render latency across a sweep of delays: latency tracks the delay ~1:1 on top of a fixed baseline render, so a 50 ms observer pushes ~19 ms to ~69 ms. Keep observer callbacks cheap and do heavy work elsewhere.

| Observer delay (ms) | Median render latency (ms) | Render minus observer (ms) | N |
|---:|---:|---:|---:|
| 0 | 17.2 | 17.2 | 10 |
| 25 | 43.5 | 18.5 | 10 |
| 50 | 68.5 | 18.5 | 10 |
| 100 | 118.8 | 18.8 | 10 |


![Render latency vs observer delay](observer_latency.png)

## Sync-search filter cost vs list size

From the `sync_search_scaling` micro (AOT, `benchmark_harness`). `SyncListView` re-runs `resolveSyncSearch` synchronously on every committed query, so this is that cost as the in-memory list grows, under a naive case-insensitive `contains`. Where the median crosses the frame budget is the practical ceiling for that predicate.

| List size | N | Median (us) | IQR (us) | Median (ms) |
|---:|---:|---:|---:|---:|
| 1,000 | 10 | 375.72 | 7.02 | 0.38 |
| 10,000 | 10 | 3,951 | 54.82 | 3.95 |
| 100,000 | 10 | 41,359 | 505.17 | 41.36 |


![Sync-search scaling](sync_search_scaling.png)

## Sync grouping (bucketing) cost vs list size

From the `bucket_by_group_scaling` micro (AOT, `benchmark_harness`). Sync grouping reorders the filtered items into contiguous sections on every committed query, so this is that cost as the list grows, over fully interleaved input for worst-case reordering. It stacks on the search-filter cost above when a list does both.

| List size | N | Median (us) | IQR (us) | Median (ms) |
|---:|---:|---:|---:|---:|
| 1,000 | 10 | 231.02 | 1.27 | 0.23 |
| 10,000 | 10 | 2,372 | 21.03 | 2.37 |
| 100,000 | 10 | 26,097 | 677.44 | 26.10 |


![Sync grouping scaling](bucket_by_group_scaling.png)

## Overlap de-dup cost vs loaded list size

From the `dedup_scaling` micro (AOT, `benchmark_harness`). The async list de-dups overlapping pages by id as a computed view over the paging state, re-walking every loaded item on each change so the stored pages stay raw and the end policy can't read an all-duplicate page as the end. Measured at its worst case: no actual overlap, so nothing collapses and every item is retained. Off the scroll path, since it runs per page-load rather than per frame. Sub-millisecond for a few thousand loaded items and climbing from there, past the frame budget at tens of thousands in one live list.

| Loaded items | N | Median (us) | IQR (us) | Median (ms) |
|---:|---:|---:|---:|---:|
| 1,000 | 10 | 302.55 | 9.61 | 0.30 |
| 10,000 | 10 | 3,388 | 86.66 | 3.39 |
| 100,000 | 10 | 39,781 | 2,306 | 39.78 |


![De-dup scaling](dedup_scaling.png)

## Per-page bookkeeping

Confirms the bookkeeping costs ~nothing. `observer_dispatch` is one no-op observer callback, the null-check plus virtual call made on each page fetch. `wrapping_overhead` is the end-policy check before each page, rebuilding the page-item-counts as loaded pages grow. Any real fetch dwarfs both.

| Micro | Metric | Median (us) |
|---|---|---:|
| `observer_dispatch` | us / dispatch | 0.011 |
| `wrapping_overhead` (1 page) | us / key | 0.554 |
| `wrapping_overhead` (10 pages) | us / key | 1.25 |
| `wrapping_overhead` (100 pages) | us / key | 7.06 |

## UI scenarios: per-frame build cost

From the profile-mode `integration_test` scenarios, real frames on this machine. `avg`, `worst` and `p99 build` are the UI-thread build cost per frame, which is where list_smith's code runs, and `missed` counts frames over the 16.67ms budget. `isp_scroll` against `bare_listview` (same items and scroll, no list_smith) is the attribution: that small delta is what list_smith adds to a plain list. `edit_transitions_none` makes the same edits as `_size`, `_fade` and `_slide` with no transition, so the gap is what animating them adds.

| Scenario | Frames | Avg build (ms) | Worst build (ms) | p99 build (ms) | Missed |
|---|---:|---:|---:|---:|---:|
| `bare_listview` | 610 | 0.61 | 2.08 | 1.77 | 0 |
| `cri_refresh` | 850 | 0.44 | 1.51 | 1.09 | 0 |
| `edit_transitions_fade` | 500 | 0.34 | 2.23 | 1.58 | 0 |
| `edit_transitions_none` | 500 | 0.29 | 2.02 | 1.61 | 0 |
| `edit_transitions_size` | 500 | 0.48 | 1.87 | 1.61 | 0 |
| `edit_transitions_slide` | 500 | 0.39 | 2.52 | 1.64 | 0 |
| `isp_scroll` | 610 | 0.68 | 2.57 | 1.85 | 0 |


![Per-frame build cost](frame_costs.png)

## UI scenarios: per-frame raster cost

The same frames on the raster thread, which draws what the build produced. `missed` counts frames over the same budget.

| Scenario | Frames | Avg raster (ms) | Worst raster (ms) | p99 raster (ms) | Missed |
|---|---:|---:|---:|---:|---:|
| `bare_listview` | 610 | 1.10 | 9.40 | 3.29 | 0 |
| `cri_refresh` | 850 | 1.07 | 12.32 | 3.09 | 0 |
| `edit_transitions_fade` | 500 | 1.13 | 10.37 | 1.92 | 0 |
| `edit_transitions_none` | 500 | 1.12 | 14.11 | 5.00 | 0 |
| `edit_transitions_size` | 500 | 1.08 | 8.61 | 1.77 | 0 |
| `edit_transitions_slide` | 500 | 1.18 | 10.73 | 5.69 | 0 |
| `isp_scroll` | 610 | 1.11 | 11.35 | 3.24 | 0 |


![Per-frame raster cost](frame_raster_costs.png)
