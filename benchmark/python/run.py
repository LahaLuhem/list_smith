#!/usr/bin/env python3
"""Entry point for the `list_smith` benchmark suite.

Thin argparse + dispatch shim. Subcommands live under `list_smith_bench/subcommands/`:

- `build`    AOT-compile all micros (parallel)
- `run`      execute micros, write per-scenario + aggregated JSON
- `report`   render PNG charts + SUMMARY.md

Workflow (run from `benchmark/python/`):

    uv sync                                    # one-time: create .venv + install deps
    uv run python run.py build                 # AOT-compile all micros
    uv run python run.py run --iterations 10 --out ../results-local/run-1/
    uv run python run.py report ../results-local/run-1/aggregated.json

`report` defaults to writing into `benchmark/reports/` (committed, referenced from the README). Pass
`--out` for ad-hoc local snapshots.

Methodology (see ../README.md): AOT compile not JIT; N >= 10; median + IQR; per-machine baselines.
The `flutter drive` UI-scenario runner + Mann-Whitney `compare` land in a later slice.
"""

from __future__ import annotations

import argparse
import sys

from list_smith_bench.config import DEFAULT_ITERATIONS, RESULTS_DIR
from list_smith_bench.subcommands.build import cmd_build
from list_smith_bench.subcommands.report import cmd_report
from list_smith_bench.subcommands.runner import cmd_run


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    _add_build_parser(sub)
    _add_run_parser(sub)
    _add_report_parser(sub)

    args = parser.parse_args(argv)
    return args.func(args)


def _add_build_parser(sub: argparse._SubParsersAction) -> None:
    parser_build = sub.add_parser("build", help="AOT-compile every micro source")
    parser_build.add_argument("--force", action="store_true", help="rebuild even if exe is fresh")
    parser_build.add_argument(
        "--workers",
        type=int,
        default=0,
        help="parallel compile workers (default: min(cpu_count, 4))",
    )
    parser_build.set_defaults(func=cmd_build)


def _add_run_parser(sub: argparse._SubParsersAction) -> None:
    parser_run = sub.add_parser("run", help="execute compiled micros N times, write JSON")
    parser_run.add_argument(
        "--iterations",
        type=int,
        default=DEFAULT_ITERATIONS,
        help=f"iterations per micro (default {DEFAULT_ITERATIONS})",
    )
    parser_run.add_argument(
        "--out",
        default=str(RESULTS_DIR / "latest"),
        help="output directory for per-scenario + aggregated JSON",
    )
    parser_run.add_argument(
        "--scenarios",
        nargs="*",
        help="restrict to named micros (default: all)",
    )
    parser_run.add_argument(
        "--duration-seconds",
        type=int,
        default=None,
        help="global wall-clock duration override (micros ignore it)",
    )
    parser_run.add_argument(
        "--duration",
        action="append",
        metavar="SCENARIO=SECONDS",
        help="per-scenario duration override (repeatable)",
    )
    parser_run.set_defaults(func=cmd_run)


def _add_report_parser(sub: argparse._SubParsersAction) -> None:
    parser_report = sub.add_parser(
        "report", help="render PNG charts + SUMMARY.md from aggregated.json"
    )
    parser_report.add_argument("results", help="path to aggregated.json")
    parser_report.add_argument(
        "--out",
        default=None,
        help="output dir for charts + SUMMARY.md (default: benchmark/reports/, committed)",
    )
    parser_report.set_defaults(func=cmd_report)


if __name__ == "__main__":
    sys.exit(main())
