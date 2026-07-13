# list_smith benchmarks

Reproducible benchmarks for `list_smith`, used to verify performance claims before they ship and to
catch regressions in the wrapped dependencies (`infinite_scroll_pagination`, `custom_refresh_indicator`).
Modelled on the maintainer's `better_internet_connectivity_checker` suite, adapted for a Flutter
widget wrapper.

The whole `benchmark/` tree is excluded from the published pub.dev tarball via
[`.pubignore`](../.pubignore); none of it ships to downstream users.

## Two layers, two fidelities

| Layer | What | Runner | Fidelity |
|---|---|---|---|
| **Micro** (`micro/`) | Pure-Dart logic (the resolvers, filters) in isolation | `dart compile exe` + [`benchmark_harness`](https://pub.dev/packages/benchmark_harness) | **Trustworthy absolute µs** (AOT) |
| **Scenario** (`app/integration_test/`) | UI-isolate blocking / frame cost, driven through the real widgets | `flutter drive --profile` + `integration_test` | **Directional**; real frames, but a Flutter app, not a pure AOT program |

The split is deliberate: a practical ceiling (e.g. "sync search suits lists up to ~N") comes from the
**micro** (real absolute microseconds), while the **scenario** confirms the cost lands on the UI
thread in one synchronous chunk. The one exception is the slow-observer scenario, whose headline is
dominated by the observer's own `sleep()` and so is faithful regardless of mode.

A scenario can only faithfully measure work that lands *inside* a frame's build or raster phase,
which is what `FrameTiming` (and the `captureFrames` helper) reports. Work that runs off-frame, on a
`Timer` or microtask, is invisible to frame timing and can't be reliably bracketed by a `Stopwatch`
around `pump()` in the live binding. The debounced sync-search resolve is exactly that (it fires
in a zero-duration `Timer` before any build), so it lives as a **micro**, not a scenario. If a
proposed scenario would measure off-frame work, make it a micro instead.

## Layout

```
benchmark/
├── harness/        shared pure-Dart utilities for the micros (result_writer, scenario_args)
├── micro/          benchmark_harness micro-benches (AOT-compiled)
├── app/            minimal Flutter host app for the UI scenarios
│   ├── integration_test/   the scenarios (+ support/ helpers, e.g. SlowListSmithObserver)
│   └── test_driver/        perf_driver.dart — writes reportData to JSON
├── python/         orchestration + analysis + reporting (uv-managed)
├── reports/        committed report output (PNGs + SUMMARY.md), linked from the package README
├── results-local/  per-machine run outputs (gitignored)
└── build/          AOT-compiled micro exes (gitignored)
```

## Prerequisites

- The Dart/Flutter SDK from [`.fvmrc`](../.fvmrc). The orchestrator prefers `fvm dart` / `fvm flutter`
  when fvm is present, with a plain-`dart` fallback.
- [`uv`](https://docs.astral.sh/uv/) for the Python orchestrator (`brew install uv`).
- For the UI scenarios: a device. Default is **macOS desktop** in profile mode. The desktop feature
  flag is enabled automatically for the run and **restored to its prior state afterwards** (see
  `python/list_smith_bench/data/utils/flutter_config.py`), so a run leaves no global toolchain change
  behind. Point at another device with `--device` (e.g. `--device emulator-5554` for a directional
  Android cross-check).

## Running

From `benchmark/python/`:

```bash
uv sync                                                  # one-time: create .venv + install deps
uv run python run.py build                               # AOT-compile the micros
uv run python run.py run --iterations 10 --out ../results-local/current/
uv run python run.py report ../results-local/current/aggregated.json --out ../results-local/current/charts/
```

`run` executes the micros and drives the UI scenarios, writing one `aggregated.json`. Useful flags:
`--skip-scenarios` (micros only, no device needed), `--skip-micros`, `--scenarios <name...>` (restrict
by name), `--device <id>`.

Lint the Python side before committing: `uv run ruff format .` then `uv run ruff check .`.

## Methodology

- **AOT compile the micros**, never JIT. `dart compile exe` gives deterministic warmup; `dart run`
  does not.
- **UI scenarios run in profile mode**, not release: profile is AOT and release-like in performance
  but keeps the VM service the driver needs (release disables it). Absolute frame numbers are
  reference-machine and target-specific; the value is the *delta* and the build-thread (our Dart)
  share. True mobile raster/jank needs a physical device and is out of scope.
- **N >= 10 iterations**; bump to 30 for a high-variance metric before claiming a regression.
- **Report median + IQR, never mean** (GC outliers skew means on a single-threaded VM).
- **`forceGc()` before each micro measurement window**; SDK pinned via `.fvmrc` (a bump invalidates a
  baseline); AC power, no competing apps.

## Baselines are per-machine, never committed

Perf numbers depend on CPU, GPU, GC tuning, OS scheduler, and thermal state, so cross-machine
comparison is misleading. `results-local/` is gitignored; every record embeds its SDK version, git
SHA, and capture date so each file is self-describing. Capture your own baseline before measuring the
delta from a change.

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

The Python analyzer reads the raw `samples` arrays for median/IQR and significance; `summary` carries
pre-computed scalars and the pivot (e.g. `list_size`).

## Reports

`reports/` is the committed output for `report` (PNGs + `SUMMARY.md`), linked from the package README
so pub.dev viewers can see the perf shape without cloning. Treat committing `reports/` as a deliberate
maintainer refresh on a quiet machine; contributor runs should pass `--out` to a local path.

## What's here now

Phase 1 (apparatus, proven end to end across both runners):

- **Micro `sync_search_scaling`** — `resolveSyncSearch` cost as the in-memory list grows (choke point:
  large sync-search filtering on the UI thread).
- **Scenario `slow_observer`** — render latency when a slow synchronous observer sits on list_smith's
  own fetch path (choke point: the observer delays the list rendering, not just a side effect).

Still to come (fan-out): the observer-dispatch and wrapping-overhead micros; the large-sync-filter,
ISP-scroll, CRI-refresh, and bare-`ListView` control scenarios; and the Mann-Whitney `compare` step.
