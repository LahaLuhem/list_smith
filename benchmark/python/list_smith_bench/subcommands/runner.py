"""`cmd_run`: execute compiled micros and drive UI scenarios, capturing JSON.

Micros run as AOT exes (batched: one subprocess per micro, N iterations inside). UI scenarios drive
a profile-mode host app via `flutter drive` + the perf driver, wrapped in `macos_desktop_enabled()`
so the desktop feature flag is enabled only for the run and restored after. Every record lands in
one aggregated.json for `report`.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

from list_smith_bench.config import (
    APP_DIR,
    BUILD_DIR,
    PERF_DRIVER_TARGET,
    PROJECT_ROOT,
    flutter_command,
)
from list_smith_bench.data.dtos.result_record import ResultRecord
from list_smith_bench.data.utils.flutter_config import macos_desktop_enabled
from list_smith_bench.data.utils.io import discover_scenarios, filter_by_name
from list_smith_bench.data.utils.meta import current_git_sha, current_package_version


def cmd_run(args: argparse.Namespace) -> int:
    """Run micros + drive UI scenarios, aggregating every record to aggregated.json."""
    outdir = Path(args.out).resolve()
    outdir.mkdir(parents=True, exist_ok=True)

    git_sha = current_git_sha()
    package_version = current_package_version()

    all_records: list[ResultRecord] = []
    if not args.skip_micros:
        all_records.extend(_run_micros(args, outdir, git_sha, package_version))
    if not args.skip_scenarios:
        all_records.extend(_run_scenarios(args, outdir, git_sha, package_version))

    aggregated_path = outdir / "aggregated.json"
    aggregated_path.write_text(json.dumps(all_records, indent=2))
    print(f"\nwrote aggregated results: {aggregated_path}")
    print(f"  total records: {len(all_records)}")

    return 0


def _run_micros(
    args: argparse.Namespace,
    outdir: Path,
    git_sha: str,
    package_version: str,
) -> list[ResultRecord]:
    """Run each compiled micro exe with `--iterations N`, returning the captured records."""
    exes = sorted(BUILD_DIR.glob("*"))
    if not exes:
        print("no compiled micros found — run `build` first", file=sys.stderr)
        return []

    records: list[ResultRecord] = []
    for exe in filter_by_name(exes, args.scenarios):
        scenario_outdir = outdir / exe.stem
        scenario_outdir.mkdir(parents=True, exist_ok=True)
        out_json = scenario_outdir / "iterations.json"
        print(f"\nrun    {exe.stem}  ({args.iterations} iterations)")
        result = subprocess.run(
            [
                str(exe),
                "--iterations",
                str(args.iterations),
                "--output",
                str(out_json),
                "--git-sha",
                git_sha,
                "--package-version",
                package_version,
                "--duration-seconds",
                "0",
            ],
            cwd=PROJECT_ROOT,
            check=False,
        )
        if result.returncode != 0:
            print(f"  FAILED (exit {result.returncode})", file=sys.stderr)
            continue
        records.extend(_read_records(out_json))
    return records


def _run_scenarios(
    args: argparse.Namespace,
    outdir: Path,
    git_sha: str,
    package_version: str,
) -> list[ResultRecord]:
    """Drive each UI scenario via `flutter drive` (profile), returning the captured records.

    Wrapped in `macos_desktop_enabled()`: the desktop feature flag is enabled for the duration and
    restored on exit, so a run leaves no global toolchain change behind. `LANG`/`LC_ALL` are set to
    UTF-8 for the CocoaPods step in the macOS build.
    """
    scenarios = list(discover_scenarios())
    if args.scenarios:
        wanted = set(args.scenarios)
        scenarios = [s for s in scenarios if s.stem in wanted]
    if not scenarios:
        return []

    env = {**os.environ, "LANG": "en_US.UTF-8", "LC_ALL": "en_US.UTF-8"}
    records: list[ResultRecord] = []
    with macos_desktop_enabled():
        for scenario in scenarios:
            scenario_outdir = outdir / scenario.stem
            scenario_outdir.mkdir(parents=True, exist_ok=True)
            out_json = scenario_outdir / "iterations.json"
            print(
                f"\ndrive  {scenario.stem}  ({args.iterations} iterations, {args.device}, profile)"
            )
            result = subprocess.run(
                [
                    *flutter_command(),
                    "drive",
                    f"--driver={PERF_DRIVER_TARGET}",
                    f"--target=integration_test/{scenario.name}",
                    "--profile",
                    "-d",
                    args.device,
                    f"--dart-define=ITERATIONS={args.iterations}",
                    f"--dart-define=OUTPUT={out_json}",
                    f"--dart-define=GIT_SHA={git_sha}",
                    f"--dart-define=PKG_VERSION={package_version}",
                ],
                cwd=APP_DIR,
                env=env,
                check=False,
            )
            if result.returncode != 0:
                print(f"  FAILED (exit {result.returncode})", file=sys.stderr)
                continue
            records.extend(_read_records(out_json))
    return records


def _read_records(out_json: Path) -> list[ResultRecord]:
    """Read a micro/scenario JSON output (an array), returning [] on missing or malformed JSON."""
    try:
        data = json.loads(out_json.read_text())
    except (json.JSONDecodeError, FileNotFoundError) as e:
        print(f"  BAD/NO JSON: {e}", file=sys.stderr)
        return []
    records = data if isinstance(data, list) else [data]
    print(f"  captured {len(records)} record(s)")
    return records
