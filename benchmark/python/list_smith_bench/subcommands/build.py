"""`cmd_build`: AOT-compile every micro source to `BUILD_DIR`.

Parallelised across workers (compiling does no measurement, so contention only hits wall-clock). A
`ThreadPoolExecutor` suffices because each worker just waits on `subprocess.run`.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import os
import subprocess
import sys
from pathlib import Path
from typing import Final

from list_smith_bench.config import (
    BUILD_DIR,
    HARNESS_DIR,
    LIB_DIR,
    MICRO_DIR,
    PROJECT_ROOT,
    dart_command,
)
from list_smith_bench.data.utils.io import discover_sources

# Roots scanned to decide whether a compiled exe is stale. Conservative: any .dart change here
# triggers a rebuild. Per-file dependency graphs aren't worth tracking; an over-rebuild is cheap.
_SOURCE_ROOTS: Final[list[Path]] = [LIB_DIR, MICRO_DIR, HARNESS_DIR]


def _max_source_mtime() -> float:
    """Latest mtime over every .dart file that could affect a compiled micro; 0.0 if none exist."""
    latest = 0.0
    for root in _SOURCE_ROOTS:
        if not root.is_dir():
            continue
        for dart_file in root.rglob("*.dart"):
            mtime = dart_file.stat().st_mtime
            latest = max(latest, mtime)
    return latest


def _is_exe_fresh(out: Path, max_src_mtime: float) -> bool:
    """Whether `out` exists and is at least as new as the latest source file."""
    if not out.exists():
        return False
    return out.stat().st_mtime >= max_src_mtime


def cmd_build(args: argparse.Namespace) -> int:
    """AOT-compile every .dart under micro/ to BUILD_DIR via `dart compile exe`.

    Skips exes already fresh unless `--force`, or unless an input .dart is newer. AOT is required
    for deterministic warmup characteristics; JIT introduces too much variance.
    """
    BUILD_DIR.mkdir(parents=True, exist_ok=True)

    sources = list(discover_sources())
    if not sources:
        print("no micro sources to build (yet)", file=sys.stderr)
        return 0

    max_src_mtime = _max_source_mtime()

    targets: list[tuple[Path, Path]] = []
    for src in sources:
        out = BUILD_DIR / src.stem
        if not args.force and _is_exe_fresh(out, max_src_mtime):
            print(f"skip   {src.relative_to(PROJECT_ROOT)} (exe up to date; --force to rebuild)")
            continue
        targets.append((src, out))

    if not targets:
        return 0

    cpu = os.cpu_count() or 1
    # Cap at 4: parallel `dart compile exe` can spike RAM (~1 GB peak each). Override --workers.
    workers = args.workers if args.workers else min(cpu, 4)
    print(f"building {len(targets)} target(s) with {workers} parallel worker(s)")

    failed: list[Path] = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        future_to_src = {pool.submit(_compile_one, src, out): src for src, out in targets}
        for future in concurrent.futures.as_completed(future_to_src):
            src = future_to_src[future]
            ok = future.result()
            print(f"{'ok  ' if ok else 'FAIL'}  {src.relative_to(PROJECT_ROOT)}")
            if not ok:
                failed.append(src)

    if failed:
        print(f"\n{len(failed)} build(s) failed", file=sys.stderr)
        return 1
    return 0


def _compile_one(src: Path, out: Path) -> bool:
    """A single `dart compile exe` invocation; suppresses stdout, surfaces stderr on failure."""
    result = subprocess.run(
        [*dart_command(), "compile", "exe", str(src), "-o", str(out)],
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        print(f"\n--- {src.name} stderr ---\n{result.stderr}\n", file=sys.stderr)
        return False
    return True
