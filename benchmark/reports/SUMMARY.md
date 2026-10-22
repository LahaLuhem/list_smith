# Benchmark results

Captured **2026-10-22** against `2.0.1` at `19e058b` on Dart SDK 3.13.5, UI scenarios on Android, iOS. N=10 iterations.

> Per-device measurements, reflecting each device's CPU, GPU, GC, OS scheduler and thermal state. Yours WILL differ, so capture your own baseline before measuring a delta.

## Observer on the critical path: a slow observer blocks rendering

The headline finding. list_smith invokes your observer *synchronously* on the page-load path, so a slow callback lands almost fully on the critical path. `slow_observer` blocks for a set delay on each callback and measures render latency across a sweep of delays: latency tracks the delay ~1:1 on top of a fixed baseline render, so a 50 ms observer pushes ~20 ms to ~70 ms on Android and ~17 ms to ~67 ms on iOS. Keep observer callbacks cheap and do heavy work elsewhere.

| Platform | Observer delay (ms) | Median render latency (ms) | Render minus observer (ms) | N |
|---|---:|---:|---:|---:|
| Android | 0 | 18.5 | 18.5 | 10 |
| Android | 25 | 54.1 | 29.1 | 10 |
| Android | 50 | 70.4 | 20.4 | 10 |
| Android | 100 | 128.5 | 28.5 | 10 |
| iOS | 0 | 17.3 | 17.3 | 10 |
| iOS | 25 | 50.8 | 25.8 | 10 |
| iOS | 50 | 67.2 | 17.2 | 10 |
| iOS | 100 | 117.9 | 17.9 | 10 |


![Render latency vs observer delay](observer_latency.png)

## Sync-search filter cost vs list size

From the `sync_search_scaling` micro (AOT, `benchmark_harness`). `SyncListView` re-runs `resolveSyncSearch` synchronously on every committed query, so this is that cost as the in-memory list grows, under a naive case-insensitive `contains`. Where the median crosses the frame budget is the practical ceiling for that predicate.

| List size | N | Median (us) | IQR (us) | Median (ms) |
|---:|---:|---:|---:|---:|
| 1,000 | 10 | 378.72 | 11.39 | 0.38 |
| 10,000 | 10 | 4,011 | 203.34 | 4.01 |
| 100,000 | 10 | 41,868 | 656.10 | 41.87 |


![Sync-search scaling](sync_search_scaling.png)

## Sync grouping (bucketing) cost vs list size

From the `bucket_by_group_scaling` micro (AOT, `benchmark_harness`). Sync grouping reorders the filtered items into contiguous sections on every committed query, so this is that cost as the list grows, over fully interleaved input for worst-case reordering. It stacks on the search-filter cost above when a list does both.

| List size | N | Median (us) | IQR (us) | Median (ms) |
|---:|---:|---:|---:|---:|
| 1,000 | 10 | 235.84 | 9.02 | 0.24 |
| 10,000 | 10 | 2,440 | 69.48 | 2.44 |
| 100,000 | 10 | 27,377 | 829.87 | 27.38 |


![Sync grouping scaling](bucket_by_group_scaling.png)

## Overlap de-dup cost vs loaded list size

From the `dedup_scaling` micro (AOT, `benchmark_harness`). The async list de-dups overlapping pages by id as a computed view over the paging state, re-walking every loaded item on each change so the stored pages stay raw and the end policy can't read an all-duplicate page as the end. Measured at its worst case: no actual overlap, so nothing collapses and every item is retained. Off the scroll path, since it runs per page-load rather than per frame. Sub-millisecond for a few thousand loaded items and climbing from there, past the frame budget at tens of thousands in one live list.

| Loaded items | N | Median (us) | IQR (us) | Median (ms) |
|---:|---:|---:|---:|---:|
| 1,000 | 10 | 300.84 | 11.65 | 0.30 |
| 10,000 | 10 | 3,313 | 91.06 | 3.31 |
| 100,000 | 10 | 38,890 | 863.38 | 38.89 |


![De-dup scaling](dedup_scaling.png)

## Per-page bookkeeping

Confirms the bookkeeping costs ~nothing. `observer_dispatch` is one no-op observer callback, the null-check plus virtual call made on each page fetch. `wrapping_overhead` is the end-policy check before each page, rebuilding the page-item-counts as loaded pages grow. Any real fetch dwarfs both.

| Micro | Metric | Median (us) |
|---|---|---:|
| `observer_dispatch` | us / dispatch | 0.011 |
| `wrapping_overhead` (1 page) | us / key | 0.167 |
| `wrapping_overhead` (10 pages) | us / key | 0.168 |
| `wrapping_overhead` (100 pages) | us / key | 0.168 |

## UI scenarios: per-frame build cost

From the profile-mode `integration_test` scenarios, real frames on one device per platform. `avg`, `worst` and `p99 build` are the UI-thread build cost per frame, which is where list_smith's code runs, and `missed` counts frames over the 16.67ms budget. `isp_scroll` against `bare_listview` (same items and scroll, no list_smith) is the attribution: that small delta is what list_smith adds to a plain list. `edit_transitions_none` makes the same edits as `_size`, `_fade` and `_slide` with no transition, so the gap is what animating them adds. `_size_scrolled` makes `_size`'s edits just above the screen, where the rows on it are held still.

| Scenario | Platform | Frames | Avg build (ms) | Worst build (ms) | p99 build (ms) | Missed |
|---|---|---:|---:|---:|---:|---:|
| `bare_listview` | Android | 607 | 1.27 | 5.50 | 3.05 | 0 |
| `bare_listview` | iOS | 610 | 0.75 | 1.62 | 1.47 | 0 |
| `cri_refresh` | Android | 850 | 0.88 | 5.96 | 2.76 | 0 |
| `cri_refresh` | iOS | 849 | 0.40 | 1.96 | 1.71 | 0 |
| `edit_transitions_fade` | Android | 500 | 1.12 | 9.53 | 8.21 | 0 |
| `edit_transitions_fade` | iOS | 500 | 0.30 | 1.87 | 1.82 | 0 |
| `edit_transitions_none` | Android | 500 | 1.14 | 13.18 | 9.34 | 0 |
| `edit_transitions_none` | iOS | 500 | 0.32 | 3.01 | 2.03 | 0 |
| `edit_transitions_size` | Android | 500 | 1.14 | 9.17 | 7.35 | 0 |
| `edit_transitions_size` | iOS | 500 | 0.44 | 1.97 | 1.72 | 0 |
| `edit_transitions_size_scrolled` | Android | 500 | 1.08 | 10.01 | 9.08 | 0 |
| `edit_transitions_size_scrolled` | iOS | 500 | 0.34 | 1.83 | 1.71 | 0 |
| `edit_transitions_slide` | Android | 500 | 1.26 | 10.70 | 9.73 | 0 |
| `edit_transitions_slide` | iOS | 500 | 0.33 | 1.86 | 1.82 | 0 |
| `isp_scroll` | Android | 610 | 1.32 | 7.28 | 4.04 | 0 |
| `isp_scroll` | iOS | 610 | 0.76 | 2.17 | 1.83 | 0 |


![Per-frame build cost](frame_costs.png)

## UI scenarios: per-frame raster cost

The same frames on the raster thread, which draws what the build produced. `missed` counts frames over the same budget. `worst` is usually the 1st captured frame, so it swings between runs.

| Scenario | Platform | Frames | Avg raster (ms) | Worst raster (ms) | p99 raster (ms) | Missed |
|---|---|---:|---:|---:|---:|---:|
| `bare_listview` | Android | 607 | 2.45 | 5.95 | 3.60 | 0 |
| `bare_listview` | iOS | 610 | 0.66 | 1.33 | 1.23 | 0 |
| `cri_refresh` | Android | 850 | 2.50 | 8.81 | 3.47 | 0 |
| `cri_refresh` | iOS | 849 | 0.71 | 64.88 | 0.83 | 1 |
| `edit_transitions_fade` | Android | 500 | 2.75 | 9.11 | 4.84 | 0 |
| `edit_transitions_fade` | iOS | 500 | 0.74 | 58.04 | 0.97 | 1 |
| `edit_transitions_none` | Android | 500 | 2.45 | 7.47 | 3.62 | 0 |
| `edit_transitions_none` | iOS | 500 | 0.72 | 1.38 | 1.20 | 0 |
| `edit_transitions_size` | Android | 500 | 2.70 | 12.49 | 4.04 | 0 |
| `edit_transitions_size` | iOS | 500 | 0.67 | 0.90 | 0.83 | 0 |
| `edit_transitions_size_scrolled` | Android | 500 | 2.66 | 5.45 | 3.59 | 0 |
| `edit_transitions_size_scrolled` | iOS | 500 | 0.57 | 1.01 | 0.70 | 0 |
| `edit_transitions_slide` | Android | 500 | 2.61 | 5.27 | 4.05 | 0 |
| `edit_transitions_slide` | iOS | 500 | 0.60 | 2.04 | 1.12 | 0 |
| `isp_scroll` | Android | 610 | 2.47 | 6.15 | 3.43 | 0 |
| `isp_scroll` | iOS | 610 | 0.60 | 1.19 | 1.05 | 0 |


![Per-frame raster cost](frame_raster_costs.png)
