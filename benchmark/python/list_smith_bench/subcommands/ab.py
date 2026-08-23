"""`cmd_ab`: run two builds' micros interleaved, alternating sides every iteration.

The gate's false positives come from run order, not statistics (issue #43): running one side's whole
block then the other's lets anything that shifts mid-job land on one side only. Alternating means a
shift hits both equally.

Interleaving is per *iteration*, so the sides alternate processes. Per micro that is one process
draw each instead of one per block, which is the granularity that matters: alternating whole micros
would leave each side on a single draw and fix nothing.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

from list_smith_bench.config import PROJECT_ROOT
from list_smith_bench.data.dtos.result_record import ResultRecord
from list_smith_bench.data.utils.meta import current_git_sha, current_package_version

# Side labels, used for the alternation order and the output keys.
CANDIDATE = "candidate"
BASELINE = "baseline"


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


def _run_once(
    exe: Path, out_json: Path, iteration: int, meta: tuple[str, str]
) -> list[ResultRecord]:
    """Run `exe` for a single iteration, returning its records stamped with the real [iteration]."""
    git_sha, package_version = meta
    result = subprocess.run(
        [
            str(exe),
            "--iterations",
            "1",
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
        print(
            f"  FAILED {exe.stem} iteration {iteration} (exit {result.returncode})", file=sys.stderr
        )

        return []

    records: list[ResultRecord] = json.loads(out_json.read_text())

    return [{**record, "iteration": iteration} for record in records]


def cmd_ab(args: argparse.Namespace) -> int:
    """Interleave two builds' micros and write one aggregated.json per side."""
    candidate_build = Path(args.candidate_build).resolve()
    baseline_build = Path(args.baseline_build).resolve()
    pairs = _paired_exes(candidate_build, baseline_build)
    if args.scenarios:
        wanted = set(args.scenarios)
        pairs = [pair for pair in pairs if pair[0] in wanted]
    if not pairs:
        print("no micros present in BOTH builds — run `build` on each side first", file=sys.stderr)

        return 1

    meta = (current_git_sha(), current_package_version())
    scratch = Path(args.scratch or args.candidate_out).resolve() / "_ab"
    scratch.mkdir(parents=True, exist_ok=True)
    collected: dict[str, list[ResultRecord]] = {CANDIDATE: [], BASELINE: []}

    for name, candidate_exe, baseline_exe in pairs:
        print(f"\nab     {name}  ({args.iterations} iterations, sides alternating)")
        exes = {CANDIDATE: candidate_exe, BASELINE: baseline_exe}
        for iteration, side in interleaved_schedule(args.iterations):
            out_json = scratch / f"{name}-{side}-{iteration}.json"
            collected[side].extend(_run_once(exes[side], out_json, iteration, meta))
        for side in (CANDIDATE, BASELINE):
            print(f"  {side:<9} {len(collected[side])} record(s) so far")

    for side, out in ((CANDIDATE, args.candidate_out), (BASELINE, args.baseline_out)):
        outdir = Path(out).resolve()
        outdir.mkdir(parents=True, exist_ok=True)
        aggregated = outdir / "aggregated.json"
        aggregated.write_text(json.dumps(collected[side], indent=2))
        print(f"\nwrote {side}: {aggregated}  ({len(collected[side])} records)")

    return 0
