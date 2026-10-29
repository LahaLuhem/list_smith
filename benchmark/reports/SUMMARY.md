# Benchmark results

Captured **2026-10-29** against `2.0.1` at `0b5980d` on Dart SDK 3.13.7, UI scenarios on Android, iOS. N=10 iterations.

> Per-device measurements, reflecting each device's CPU, GPU, GC, OS scheduler and thermal state. Yours WILL differ, so capture your own baseline before measuring a delta.

## Observer on the critical path: a slow observer blocks rendering

The headline finding. list_smith invokes your observer *synchronously* on the page-load path, so a slow callback lands almost fully on the critical path. `slow_observer` blocks for a set delay on each callback and measures render latency across a sweep of delays: latency tracks the delay ~1:1 on top of a fixed baseline render, so a 50 ms observer pushes ~20 ms to ~70 ms on Android and ~17 ms to ~67 ms on iOS. Keep observer callbacks cheap and do heavy work elsewhere.

| Platform | Observer delay (ms) | Median render latency (ms) | Render minus observer (ms) | N |
|---|---:|---:|---:|---:|
| Android | 0 | 18.8 | 18.8 | 10 |
| Android | 25 | 54.3 | 29.3 | 10 |
| Android | 50 | 70.5 | 20.5 | 10 |
| Android | 100 | 121.6 | 21.6 | 10 |
| iOS | 0 | 18.0 | 18.0 | 10 |
| iOS | 25 | 50.7 | 25.7 | 10 |
| iOS | 50 | 67.1 | 17.1 | 10 |
| iOS | 100 | 117.7 | 17.7 | 10 |


![Render latency vs observer delay](observer_latency.png)

## Sync-search filter cost vs list size

From the `sync_search_scaling` micro (AOT, `benchmark_harness`). `SyncListView` re-runs `resolveSyncSearch` synchronously on every committed query, so this is that cost as the in-memory list grows, under a naive case-insensitive `contains`. Where the median crosses the frame budget is the practical ceiling for that predicate.

| List size | N | Median (us) | IQR (us) | Median (ms) |
|---:|---:|---:|---:|---:|
| 1,000 | 10 | 373.21 | 9.49 | 0.37 |
| 10,000 | 10 | 3,973 | 87.60 | 3.97 |
| 100,000 | 10 | 41,447 | 1,020 | 41.45 |


![Sync-search scaling](sync_search_scaling.png)

## Sync grouping (bucketing) cost vs list size

From the `bucket_by_group_scaling` micro (AOT, `benchmark_harness`). Sync grouping reorders the filtered items into contiguous sections on every committed query, so this is that cost as the list grows, over fully interleaved input for worst-case reordering. It stacks on the search-filter cost above when a list does both.

| List size | N | Median (us) | IQR (us) | Median (ms) |
|---:|---:|---:|---:|---:|
| 1,000 | 10 | 240.21 | 8.70 | 0.24 |
| 10,000 | 10 | 2,464 | 155.17 | 2.46 |
| 100,000 | 10 | 27,204 | 1,211 | 27.20 |


![Sync grouping scaling](bucket_by_group_scaling.png)

## Overlap de-dup cost vs loaded list size

From the `dedup_scaling` micro (AOT, `benchmark_harness`). The async list de-dups overlapping pages by id as a computed view over the paging state, re-walking every loaded item on each change so the stored pages stay raw and the end policy can't read an all-duplicate page as the end. Measured at its worst case: no actual overlap, so nothing collapses and every item is retained. Off the scroll path, since it runs per page-load rather than per frame. Sub-millisecond for a few thousand loaded items and climbing from there, past the frame budget at tens of thousands in one live list.

| Loaded items | N | Median (us) | IQR (us) | Median (ms) |
|---:|---:|---:|---:|---:|
| 1,000 | 10 | 290.75 | 5.18 | 0.29 |
| 10,000 | 10 | 3,241 | 67.21 | 3.24 |
| 100,000 | 10 | 38,040 | 871.93 | 38.04 |


![De-dup scaling](dedup_scaling.png)

## Per-page bookkeeping

Confirms the bookkeeping costs ~nothing. `observer_dispatch` is one no-op observer callback, the null-check plus virtual call made on each page fetch. `wrapping_overhead` is the end-policy check before each page, rebuilding the page-item-counts as loaded pages grow. Any real fetch dwarfs both.

| Micro | Metric | Median (us) |
|---|---|---:|
| `observer_dispatch` | us / dispatch | 0.011 |
| `wrapping_overhead` (1 page) | us / key | 0.165 |
| `wrapping_overhead` (10 pages) | us / key | 0.165 |
| `wrapping_overhead` (100 pages) | us / key | 0.166 |

## UI scenarios: per-frame build cost

From the profile-mode `integration_test` scenarios, real frames on one device per platform. `avg`, `worst` and `p99 build` are the UI-thread build cost per frame, which is where list_smith's code runs, and `missed` counts frames over the 16.67ms budget. `isp_scroll` against `bare_listview` (same items and scroll, no list_smith) is the attribution: that small delta is what list_smith adds to a plain list. `sync_scroll` is the same scroll over a `ListSmith.sync` list with ids. `edit_transitions_none` makes the same edits as `_size`, `_fade` and `_slide` with no transition, so the gap is what animating them adds. `_size_scrolled` makes `_size`'s edits just above the screen, where the rows on it are held still.

| Scenario | Platform | Frames | Avg build (ms) | Worst build (ms) | p99 build (ms) | Missed |
|---|---|---:|---:|---:|---:|---:|
| `bare_listview` | Android | 610 | 1.22 | 4.79 | 2.76 | 0 |
| `bare_listview` | iOS | 610 | 0.71 | 1.58 | 1.34 | 0 |
| `cri_refresh` | Android | 849 | 0.84 | 4.70 | 2.44 | 0 |
| `cri_refresh` | iOS | 850 | 0.35 | 1.83 | 1.47 | 0 |
| `edit_transitions_fade` | Android | 500 | 1.11 | 9.36 | 8.08 | 0 |
| `edit_transitions_fade` | iOS | 500 | 0.29 | 1.79 | 1.71 | 0 |
| `edit_transitions_none` | Android | 500 | 1.04 | 13.98 | 8.43 | 0 |
| `edit_transitions_none` | iOS | 500 | 0.25 | 2.92 | 1.73 | 0 |
| `edit_transitions_size` | Android | 500 | 1.10 | 9.11 | 7.09 | 0 |
| `edit_transitions_size` | iOS | 500 | 0.38 | 1.90 | 1.59 | 0 |
| `edit_transitions_size_scrolled` | Android | 500 | 1.07 | 9.83 | 8.44 | 0 |
| `edit_transitions_size_scrolled` | iOS | 500 | 0.34 | 1.69 | 1.63 | 0 |
| `edit_transitions_slide` | Android | 500 | 1.30 | 9.95 | 8.87 | 0 |
| `edit_transitions_slide` | iOS | 500 | 0.32 | 1.93 | 1.78 | 0 |
| `isp_scroll` | Android | 610 | 1.29 | 4.75 | 3.21 | 0 |
| `isp_scroll` | iOS | 610 | 0.76 | 2.38 | 1.70 | 0 |
| `sync_scroll` | Android | 610 | 1.27 | 5.39 | 3.79 | 0 |
| `sync_scroll` | iOS | 610 | 0.72 | 2.84 | 1.36 | 0 |


![Per-frame build cost](frame_costs.png)

## UI scenarios: per-frame raster cost

The same frames on the raster thread, which draws what the build produced. `missed` counts frames over the same budget. `worst` is usually the 1st captured frame, so it swings between runs.

| Scenario | Platform | Frames | Avg raster (ms) | Worst raster (ms) | p99 raster (ms) | Missed |
|---|---|---:|---:|---:|---:|---:|
| `bare_listview` | Android | 610 | 2.38 | 6.50 | 3.16 | 0 |
| `bare_listview` | iOS | 610 | 0.62 | 1.54 | 1.07 | 0 |
| `cri_refresh` | Android | 849 | 2.44 | 8.59 | 3.62 | 0 |
| `cri_refresh` | iOS | 850 | 0.55 | 3.47 | 0.71 | 0 |
| `edit_transitions_fade` | Android | 500 | 2.71 | 8.58 | 4.73 | 0 |
| `edit_transitions_fade` | iOS | 500 | 0.62 | 2.19 | 0.91 | 0 |
| `edit_transitions_none` | Android | 500 | 2.43 | 8.40 | 3.58 | 0 |
| `edit_transitions_none` | iOS | 500 | 0.57 | 1.57 | 0.97 | 0 |
| `edit_transitions_size` | Android | 500 | 2.48 | 5.80 | 3.73 | 0 |
| `edit_transitions_size` | iOS | 500 | 0.56 | 0.81 | 0.70 | 0 |
| `edit_transitions_size_scrolled` | Android | 500 | 2.74 | 8.13 | 3.92 | 0 |
| `edit_transitions_size_scrolled` | iOS | 500 | 0.56 | 0.98 | 0.70 | 0 |
| `edit_transitions_slide` | Android | 500 | 2.71 | 6.71 | 4.05 | 0 |
| `edit_transitions_slide` | iOS | 500 | 0.59 | 2.09 | 1.12 | 0 |
| `isp_scroll` | Android | 610 | 2.48 | 6.35 | 3.56 | 0 |
| `isp_scroll` | iOS | 610 | 0.62 | 1.32 | 1.16 | 0 |
| `sync_scroll` | Android | 610 | 2.56 | 6.64 | 4.44 | 0 |
| `sync_scroll` | iOS | 610 | 0.61 | 1.29 | 1.09 | 0 |


![Per-frame raster cost](frame_raster_costs.png)
