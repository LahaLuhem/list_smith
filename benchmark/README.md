# list_smith benchmarks

Reproducible benchmarks that prove `list_smith`'s performance claims before they ship, and catch
regressions in its paging and in the wrapped `custom_refresh_indicator`.
[`.pubignore`](../.pubignore) keeps the whole tree out of the pub.dev tarball.

## 2 layers, 2 fidelities

| Layer | What | Runner | Fidelity |
|---|---|---|---|
| **Micro** (`micro/`) | Pure-Dart logic (the resolvers, filters) in isolation | `dart compile exe` + [`benchmark_harness`](https://pub.dev/packages/benchmark_harness) | **Trustworthy absolute µs** (AOT) |
| **Scenario** (`app/integration_test/`) | UI-isolate blocking / frame cost, driven through the real widgets | `flutter drive --profile` + `integration_test` | **Directional**: real frames, but a Flutter app, not a pure AOT program |

A practical ceiling ("sync search suits lists up to ~N") comes from a **micro**, and a **scenario**
confirms the cost lands on the UI thread in one chunk. `slow_observer` is faithful either way, since
the observer's own `sleep()` dominates it.

A scenario only sees work inside a frame's build or raster, which is what `FrameTiming` reports.
Work on a `Timer` or a microtask, like the debounced sync-search resolve, can't be bracketed by a
`Stopwatch` around `pump()`. **Off-frame work is a micro.**

## Layout

```text
benchmark/
├── harness/        shared pure-Dart utilities for the micros
├── micro/          benchmark_harness micro-benches (AOT-compiled)
├── app/            minimal Flutter host app for the UI scenarios
│   ├── integration_test/   the scenarios, with support/ helpers
│   └── test_driver/        perf_driver.dart, writes reportData to JSON
├── python/         orchestration, analysis and reporting (uv-managed)
├── reports/        the committed report (PNGs + SUMMARY.md), linked from the package README
├── results-local/  per-machine run outputs (gitignored)
└── build/          AOT-compiled micro exes (gitignored)
```

## Prerequisites

- The SDK from [`.fvmrc`](../.fvmrc). The orchestrator uses `fvm dart` and `fvm flutter` when fvm
  is there, plain `dart` otherwise.
- [`uv`](https://docs.astral.sh/uv/) for the Python side.
- A device for the UI scenarios. **macOS desktop** in profile mode by default, needing nothing
  attached, with the desktop feature flag on for the run and **restored after**. The committed
  report comes from phones, one run per platform with `--device <id>` (`flutter devices` lists
  them), since a desktop window losing focus swamps its timings.
- For an iPhone, signing in an untracked `app/ios/Flutter/LocalSigning.xcconfig` holding your
  `DEVELOPMENT_TEAM` and `PRODUCT_BUNDLE_IDENTIFIER`.

## Running

From `benchmark/python/`:

```bash
uv sync                                                  # one-time: create .venv + install deps
uv run python run.py build                               # AOT-compile the micros
uv run python run.py run --iterations 10 --out ../results-local/current/
uv run python run.py report ../results-local/current/aggregated.json --out ../results-local/current/charts/
```

`run` runs the micros and drives the scenarios into one `aggregated.json`. Useful flags:
`--skip-scenarios` (micros only, no device), `--skip-micros`, `--device <id>`, and
`--scenarios <file...>`, which takes file names without `.dart` (`dedup_scaling`,
`isp_scroll_test`).

The committed report takes a micro run on the host and a UI run per phone:

```bash
uv run python run.py run --skip-scenarios --iterations 10 --out ../results-local/micros/
uv run python run.py run --skip-micros --device <android id> --iterations 10 --out ../results-local/android/
uv run python run.py run --skip-micros --device <ios id> --iterations 10 --out ../results-local/ios/
uv run python run.py report ../results-local/{micros,android,ios}/aggregated.json
```

Before committing Python: `uv run ruff format .`, then `uv run ruff check .`.

## Methodology

- **Micros run AOT, never JIT.** `dart compile exe` warms up deterministically, `dart run` doesn't.
- **Scenarios run in profile mode,** which is AOT and release-like but keeps the VM service the
  driver needs. Absolute frame numbers are device-specific, so the value is the *delta* and the
  build-thread share.
- **N >= 10 iterations,** 30 for a noisy metric before claiming a regression.
- **Median and IQR, never mean,** since GC outliers skew a mean on a single-threaded VM.
- **`forceGc()` before each micro window,** the SDK pinned (a bump invalidates a baseline), on AC
  power with no competing apps.

## Baselines are per-machine, never committed

CPU, GPU, GC, the scheduler and heat all move the numbers, so comparing machines misleads.
`results-local/` is gitignored, and every record carries its SDK version, git SHA and capture date.
Capture your own baseline before measuring a change.

Android runs light frames on slow clocks, since the governor keeps idle-looking cores slow. So a
light scenario like `edit_transitions` reads several times slower than on iOS, and closes in once
background load holds the clocks up.

## CI regression gate

[`benchmark.yml`](../.github/workflows/benchmark.yml) builds and runs the micros twice on one
runner, the PR head and `origin/main` in turn at one path, and fails on a significant regression
past the threshold. 2 things about it are deliberate.

**It only triggers on code it times:** `lib/**`, `benchmark/micro/**`, `benchmark/harness/**` and
the workflow. A PR touching only the Python, the host app or docs has no timing delta, and widening
the filter to `benchmark/**` would make every such PR pay for nothing.

**Nearly all of it is measurement,** `micros x pivots x iterations x 2 sides` cells, each holding a
fixed window, and it stays serial:

- Both sides **share one runner,** since GitHub VMs vary run to run, which also rules out a cached
  baseline.
- They **build one after the other, at one path.** Private names hash the file path, so a 2nd build
  directory reorders the same code's data, which x86 runners have timed over 20% apart.
- The micros **never run concurrently,** since CPU contention corrupts the timings.

**The window is the lever.** `benchmark_harness`'s `measure()` hardcodes 2s per cell
(`minimumMeasureDurationMillis`), so a nanosecond dispatch costs as much as a long scan.
[`harness/measure.dart`](harness/measure.dart) opens it up, and `ab` takes a shorter window than
`run`. At 500ms a sweep ran 2.8x faster, every median moved under 3.1%, and within-side spread held.

Still too slow? Shard by scenario across jobs: `compare` pairs strictly on `(scenario, metric)`, and
`ab --scenarios` already takes the split. Fewer pivots or iterations work too, but cost detection
power, which [`test_gate_power.py`](python/tests/test_gate_power.py) pins.

## Result JSON schema

Each micro and scenario emits records like this
([`result_writer.dart`](harness/result_writer.dart)):

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

The analyzer reads the raw `samples` for median, IQR and significance. `summary` carries
pre-computed scalars plus the pivot (`list_size`, say). A scenario's record also carries
`iterations`, since it holds every iteration's frames, and `platform`.

## Reports

`reports/` is `report`'s committed output, linked from the package README so pub.dev readers see the
shape without cloning. Refreshing it is the maintainer's call, so a contributor run passes `--out`
to a local path. `SUMMARY.md` dates itself from the records' `started_at`, so re-rendering an old
capture keeps its date.

## What's measured

Each micro (`micro/`) and scenario (`app/integration_test/`) says what it measures at the top of its
file.

`compare` diffs 2 runs with a Mann-Whitney test, and `ab` interleaves 2 builds' micros so run-order
drift lands on both sides. Each side runs a copy of its build from a path of the same length, so
neither starts laid out differently in memory. A micro that's the same program on both sides isn't
timed: its 2 exes are byte-identical, or `build` hashed the same inputs, as the compiler lists them,
into `build/inputs/`. Only the hash works on macOS, which stamps every build.
