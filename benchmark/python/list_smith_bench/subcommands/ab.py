"""`cmd_ab`: run 2 builds' micros interleaved, alternating sides every iteration.

The gate's false positives come from run order, not statistics: running one side's whole block then
the other's lets anything that shifts mid-job land on one side only. Alternating means a shift hits
both equally.

Interleaving is per *iteration*, so the sides alternate processes. Per micro that is one process
draw each instead of one per block, which is the granularity that matters. Alternating whole micros
would leave each side on a single draw and fix nothing.
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Final

from list_smith_bench.config import PROJECT_ROOT
from list_smith_bench.data.dtos.result_record import ResultRecord
from list_smith_bench.data.utils.meta import current_git_sha, current_package_version

# Side labels, used for the alternation order and the output keys.
CANDIDATE = "candidate"
BASELINE = "baseline"

# What a side's process sees in its paths. Equal lengths, so neither side's process starts with its
# memory laid out differently from the other's.
_SIDE_TOKENS: Final[dict[str, str]] = {CANDIDATE: "a", BASELINE: "b"}


def interleaved_schedule(iterations: int) -> list[tuple[int, str]]:
    """The (iteration, side) order for one micro: alternate sides, and alternate who goes first.

    Swapping the leader each iteration keeps the within-pair position from favouring either side,
    which a fixed `candidate, baseline, candidate, baseline` order would not.
    """
    schedule: list[tuple[int, str]] = []
    for iteration in range(iterations):
        order = (CANDIDATE, BASELINE) if iteration % 2 == 0 else (BASELINE, CANDIDATE)
        schedule.extend((iteration, side) for side in order)

    return schedule


def _paired_exes(candidate_build: Path, baseline_build: Path) -> list[tuple[str, Path, Path]]:
    """Micros present in both builds, as `(name, candidate exe, baseline exe)`, sorted by name."""
    candidates = {exe.stem: exe for exe in candidate_build.glob("*") if exe.is_file()}
    baselines = {exe.stem: exe for exe in baseline_build.glob("*") if exe.is_file()}

    shared = sorted(candidates.keys() & baselines.keys())

    return [(name, candidates[name], baselines[name]) for name in shared]


def staged_exe(scratch: Path, name: str, side: str) -> Path:
    """Where `side`'s copy of micro `name` runs from."""
    return scratch / "bin" / _SIDE_TOKENS[side] / name


def _out_json(scratch: Path, name: str, side: str, iteration: int) -> Path:
    return scratch / f"{name}-{_SIDE_TOKENS[side]}-{iteration}.json"


def run_command(
    scratch: Path,
    name: str,
    side: str,
    iteration: int,
    meta: tuple[str, str],
    measure_millis: int,
) -> list[str]:
    """The command `side` runs for one iteration of micro `name`."""
    git_sha, package_version = meta

    return [
        str(staged_exe(scratch, name, side)),
        "--iterations",
        "1",
        "--output",
        str(_out_json(scratch, name, side, iteration)),
        "--git-sha",
        git_sha,
        "--package-version",
        package_version,
        "--measure-millis",
        str(measure_millis),
    ]


def _run_once(command: list[str], out_json: Path, iteration: int) -> list[ResultRecord]:
    """Run one iteration's `command`, returning its records stamped with the real [iteration]."""
    result = subprocess.run(command, cwd=PROJECT_ROOT, check=False)
    if result.returncode != 0:
        print(
            f"  FAILED {Path(command[0]).name} iteration {iteration} (exit {result.returncode})",
            file=sys.stderr,
        )

        return []

    records: list[ResultRecord] = json.loads(out_json.read_text())

    return [{**record, "iteration": iteration} for record in records]


def cmd_ab(args: argparse.Namespace) -> int:
    """Interleave 2 builds' micros and write one aggregated.json per side."""
    candidate_build = Path(args.candidate_build).resolve()
    baseline_build = Path(args.baseline_build).resolve()
    pairs = _paired_exes(candidate_build, baseline_build)
    if args.scenarios:
        wanted = set(args.scenarios)
        pairs = [pair for pair in pairs if pair[0] in wanted]
    if not pairs:
        print("no micros in both builds. Run `build` on each side first", file=sys.stderr)

        return 1

    meta = (current_git_sha(), current_package_version())
    scratch = Path(args.scratch or args.candidate_out).resolve() / "_ab"
    scratch.mkdir(parents=True, exist_ok=True)
    collected: dict[str, list[ResultRecord]] = {CANDIDATE: [], BASELINE: []}

    for name, candidate_exe, baseline_exe in pairs:
        print(
            f"\nab     {name}  ({args.iterations} iterations, sides alternating, "
            f"{args.measure_millis}ms window)"
        )
        for side, exe in ((CANDIDATE, candidate_exe), (BASELINE, baseline_exe)):
            staged = staged_exe(scratch, name, side)
            staged.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(exe, staged)
        for iteration, side in interleaved_schedule(args.iterations):
            command = run_command(scratch, name, side, iteration, meta, args.measure_millis)
            out_json = _out_json(scratch, name, side, iteration)
            collected[side].extend(_run_once(command, out_json, iteration))
        for side in (CANDIDATE, BASELINE):
            print(f"  {side:<9} {len(collected[side])} record(s) so far")

    for side, out in ((CANDIDATE, args.candidate_out), (BASELINE, args.baseline_out)):
        outdir = Path(out).resolve()
        outdir.mkdir(parents=True, exist_ok=True)
        aggregated = outdir / "aggregated.json"
        aggregated.write_text(json.dumps(collected[side], indent=2))
        print(f"\nwrote {side}: {aggregated}  ({len(collected[side])} records)")

    return 0
