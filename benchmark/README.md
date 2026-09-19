# list_smith benchmarks

Reproducible benchmarks for `list_smith`: proving performance claims before they ship, and catching
regressions in the wrapped dependencies (`infinite_scroll_pagination`, `custom_refresh_indicator`).
Modelled on the maintainer's `better_internet_connectivity_checker` suite, adapted for a widget
wrapper.

[`.pubignore`](../.pubignore) excludes the whole `benchmark/` tree from the pub.dev tarball, so none
of it reaches downstream users.

## 2 layers, 2 fidelities

| Layer | What | Runner | Fidelity |
|---|---|---|---|
| **Micro** (`micro/`) | Pure-Dart logic (the resolvers, filters) in isolation | `dart compile exe` + [`benchmark_harness`](https://pub.dev/packages/benchmark_harness) | **Trustworthy absolute µs** (AOT) |
| **Scenario** (`app/integration_test/`) | UI-isolate blocking / frame cost, driven through the real widgets | `flutter drive --profile` + `integration_test` | **Directional**; real frames, but a Flutter app, not a pure AOT program |

The split is deliberate. A practical ceiling ("sync search suits lists up to ~N") comes from the
**micro**, which gives real absolute microseconds, while the **scenario** confirms the cost lands on
the UI thread in one synchronous chunk. `slow_observer` is the exception: its headline is dominated
by the observer's own `sleep()`, so it is faithful either way.

A scenario can only faithfully measure work inside a frame's build or raster phase, which is what
`FrameTiming` reports. Work on a `Timer` or a microtask is invisible to frame timing and can't be
bracketed reliably by a `Stopwatch` around `pump()`. The debounced sync-search resolve is exactly
that, firing in a zero-duration `Timer` before any build, which is why it is a micro. **If a
proposed scenario would measure off-frame work, make it a micro instead.**

## Layout

```text
benchmark/
├── harness/        shared pure-Dart utilities for the micros (result_writer, scenario_args)
├── micro/          benchmark_harness micro-benches (AOT-compiled)
├── app/            minimal Flutter host app for the UI scenarios
│   ├── integration_test/   the scenarios (+ support/ helpers, e.g. SlowListSmithObserver)
│   └── test_driver/        perf_driver.dart, writes reportData to JSON
├── python/         orchestration + analysis + reporting (uv-managed)
├── reports/        committed report output (PNGs + SUMMARY.md), linked from the package README
├── results-local/  per-machine run outputs (gitignored)
└── build/          AOT-compiled micro exes (gitignored)
```

## Prerequisites

- The Dart/Flutter SDK from [`.fvmrc`](../.fvmrc). The orchestrator prefers `fvm dart` and
  `fvm flutter` when fvm is present, falling back to plain `dart`.
- [`uv`](https://docs.astral.sh/uv/) for the Python orchestrator (`brew install uv`).
- For the UI scenarios, a device. **macOS desktop** in profile mode by default, with the desktop
  feature flag enabled for the run and **restored afterwards**, so a run leaves no global toolchain
  change behind. Point at another with `--device` (say `--device emulator-5554` for a directional
  Android cross-check).

## Running

From `benchmark/python/`:

```bash
uv sync                                                  # one-time: create .venv + install deps
uv run python run.py build                               # AOT-compile the micros
uv run python run.py run --iterations 10 --out ../results-local/current/
uv run python run.py report ../results-local/current/aggregated.json --out ../results-local/current/charts/
```

`run` executes the micros and drives the UI scenarios, writing one `aggregated.json`. Useful
flags: `--skip-scenarios` (micros only, no device needed), `--skip-micros`,
`--scenarios <name...>`, `--device <id>`.

Lint the Python side before committing: `uv run ruff format .` then `uv run ruff check .`.

## Methodology

- **AOT compile the micros**, never JIT. `dart compile exe` gives deterministic warmup and
  `dart run` doesn't.
- **UI scenarios run in profile mode**, not release: profile is AOT and release-like in performance
  while keeping the VM service the driver needs. Absolute frame numbers are machine- and
  target-specific, so the value is the *delta* and the build-thread share. Real mobile raster and
  jank need a physical device and are out of scope.
- **N >= 10 iterations**, bumped to 30 for a high-variance metric before claiming a regression.
- **Report median and IQR, never mean.** GC outliers skew means on a single-threaded VM.
- **`forceGc()` before each micro measurement window.** SDK pinned via `.fvmrc`, since a bump
  invalidates a baseline. AC power, no competing apps.

## Baselines are per-machine, never committed

Perf numbers depend on CPU, GPU, GC tuning, OS scheduler and thermal state, so comparing across
machines is misleading. `results-local/` is gitignored, and every record embeds its SDK version, git
SHA and capture date, so each file is self-describing. Capture your own baseline before measuring
the delta from a change.

## CI regression gate

[`.github/workflows/benchmark.yml`](../.github/workflows/benchmark.yml) builds and runs the
micros twice on one runner (the PR head and an `origin/main` worktree) and fails the job on a
significant regression past the threshold. 2 things about it are deliberate, so know them before
trying to speed it up.

**It only triggers on code whose timing it measures:** `lib/**`, `benchmark/micro/**`,
`benchmark/harness/**`, and the workflow file. A PR touching only `benchmark/python`, the host app
or docs has no micro-timing delta to catch, so it skips the gate. Keep that filter tight. Widening
it back to `benchmark/**` makes every unrelated PR pay the full cost for nothing.

**Nearly all of it is measurement, not setup.** Cached Flutter setup and both AOT builds come to
well under a minute. The rest is `micros x pivots x iterations x 2 sides` cells, each holding a fixed
time window. Two things keep it serial:

- Candidate and baseline **must share one runner**, because GitHub VMs vary run to run and a
  cross-machine baseline would drown real regressions in noise. Caching a baseline across runs is
  out for the same reason.
- The micros **can't run concurrently**, since CPU contention corrupts the very timings being
  measured.

**The window is the lever.** `benchmark_harness`'s `measure()` hardcodes 2s per cell
(`minimumMeasureDurationMillis`), so an 11ns dispatch costs the same as a 41ms scan.
[`harness/measure.dart`](harness/measure.dart) opens it up, and `ab` takes a shorter window than
`run` does. At 500ms a sweep ran 2.8x faster, every median moved under 3.1%, and within-side spread
was unchanged.

Still too slow? Shard by scenario across jobs. `compare` pairs strictly on `(scenario, metric)`, so
nothing compares across shards, and `ab --scenarios` already takes the split. Trimming pivots or
iterations works too, but both cost detection power, which
[`test_gate_power.py`](python/tests/test_gate_power.py) pins.

## Result JSON schema

Each micro/scenario emits records conforming to (see `harness/result_writer.dart`):

```json
{
  "scenario": "<name>",
  "iteration": 0,
  "sdk_version": "<string>",
  "package_version": "<string>",
  "git_sha": "<string>",
  "started_at": "<ISO-8601 UTC>",
  "samples": { "<metric>": [<numbers>, ...] },
  "summary": { "<aggregate>": <number> }
}
```

The analyzer reads the raw `samples` arrays for median, IQR and significance. `summary` carries
pre-computed scalars plus the pivot (`list_size`, say).

## Reports

`reports/` is the committed output of `report` (PNGs plus `SUMMARY.md`), linked from the package
README so pub.dev viewers see the perf shape without cloning. Committing it is a deliberate
maintainer refresh on a quiet machine, so contributor runs should pass `--out` to a local path.
`SUMMARY.md` takes its capture date from the records' own `started_at`, so re-rendering an old
capture reproduces it rather than restamping it with today.

## What's measured

| Micro (`micro/`) | Measures |
|---|---|
| `sync_search_scaling` | `resolveSyncSearch` cost as the in-memory list grows |
| `bucket_by_group_scaling` | `bucketByGroup` cost as the list grows, over interleaved input |
| `header_flags_scaling` | `headerFlagsByFirstSighting` cost as the loaded list grows, over a lazy flatten of pages |
| `dedup_scaling` | `itemId` de-dup cost as the loaded list grows, with no real overlap |
| `observer_dispatch` | one no-op observer callback through list_smith's wrapping |
| `wrapping_overhead` | the per-`getNextPageKey` end-policy work as loaded pages grow |

| Scenario (`app/integration_test/`) | Measures |
|---|---|
| `slow_observer` | render latency when a slow synchronous observer sits on the fetch path |
| `isp_scroll` | per-frame build cost scrolling a `ListSmith.async` list |
| `bare_listview` | the same scroll over a plain `ListView.builder`, the attribution control |
| `cri_refresh` | per-frame build cost across full pull-to-refresh cycles |

On top of those, `compare` diffs 2 runs with a Mann-Whitney test, and `ab` runs 2 builds' micros
interleaved so run-order drift lands on both sides equally.
