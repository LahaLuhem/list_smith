"""Package-wide constants + the fvm-aware `dart` invocation.

All values are `Final[...]` — reassignment is a bug. Nothing here imports from other
`list_smith_bench` modules (would create a cycle).
"""

from __future__ import annotations

import shutil
from pathlib import Path
from typing import Final

# ---- paths ----------------------------------------------------------------

THIS_FILE: Final[Path] = Path(__file__).resolve()
# THIS_FILE lives at benchmark/python/list_smith_bench/config.py. Walk up:
#   .parent         -> benchmark/python/list_smith_bench/
#   .parent.parent  -> benchmark/python/            (PYTHON_DIR)
PYTHON_DIR: Final[Path] = THIS_FILE.parent.parent
BENCHMARK_DIR: Final[Path] = PYTHON_DIR.parent
PROJECT_ROOT: Final[Path] = BENCHMARK_DIR.parent
LIB_DIR: Final[Path] = PROJECT_ROOT / "lib"
MICRO_DIR: Final[Path] = BENCHMARK_DIR / "micro"
HARNESS_DIR: Final[Path] = BENCHMARK_DIR / "harness"
BUILD_DIR: Final[Path] = BENCHMARK_DIR / "build"
RESULTS_DIR: Final[Path] = BENCHMARK_DIR / "results-local"
# The canonical committed report dir. `report` writes here by default; `--out` overrides. Referenced
# from the package README via committed PNGs, so contributors only overwrite it when refreshing the
# maintainer baseline.
REPORTS_DIR: Final[Path] = BENCHMARK_DIR / "reports"

# ---- run defaults ---------------------------------------------------------

DEFAULT_ITERATIONS: Final[int] = 10
# Warmup iterations the analyzer trims when aggregating; the entrypoint still emits every iteration.
WARMUP_ITERATIONS: Final[int] = 2
# Micros ignore duration (benchmark_harness self-times); the orchestrator still passes something.
FALLBACK_DURATION: Final[int] = 10

# Entrypoints that emit MORE THAN ONE record per iteration (sync_search_scaling: one per list size).
# Used when picking a representative "iterations per scenario" figure for report headers.
MULTI_RECORD_SCENARIOS: Final[frozenset[str]] = frozenset({"sync_search_scaling"})

# ---- chart style ----------------------------------------------------------

# 150 DPI is sharp on retina without bloating the committed PNGs.
CHART_DPI: Final[int] = 150
CHART_PALETTE: Final[str] = "Set2"
# 60 Hz frame budget in microseconds; the reference line on UI-cost charts.
FRAME_BUDGET_MICROS_60HZ: Final[int] = 16667
# Significance threshold for the (deferred) Mann-Whitney compare step.
SIGNIFICANCE_THRESHOLD: Final[float] = 0.05


def dart_command() -> list[str]:
    """The `dart` invocation, honouring the project's `.fvmrc` pin when fvm is available.

    Mirrors `scripts/release.sh`: prefer `fvm dart` when `.fvmrc` pins an SDK and fvm is on PATH, so
    the benchmark compiles against the same SDK as the rest of the toolchain; fall back to a plain
    `dart` for contributors who manage the SDK themselves.
    """
    fvmrc = PROJECT_ROOT / ".fvmrc"
    if fvmrc.exists() and shutil.which("fvm"):
        return ["fvm", "dart"]
    return ["dart"]
