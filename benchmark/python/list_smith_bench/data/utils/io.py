"""Filesystem + JSON helpers.

`discover_sources` walks the micro dir. `filter_by_name` restricts a path list to a user-supplied
set. `resolve_outdir` picks where charts/markdown land. `load_aggregated` is the single JSON-read
path, so schema validation (if ever needed) has one home.
"""

from __future__ import annotations

import argparse
import json
from collections.abc import Iterable
from pathlib import Path

from list_smith_bench.config import MICRO_DIR, REPORTS_DIR, SCENARIOS_DIR
from list_smith_bench.data.dtos.result_record import ResultRecord


def discover_sources() -> Iterable[Path]:
    """Yield every .dart micro entry-point to AOT-compile."""
    if MICRO_DIR.exists():
        yield from sorted(MICRO_DIR.glob("*.dart"))


def discover_scenarios() -> Iterable[Path]:
    """Yield every UI scenario entry-point (integration_test/*.dart; support/ excluded)."""
    if SCENARIOS_DIR.exists():
        yield from sorted(SCENARIOS_DIR.glob("*.dart"))


def filter_by_name(exes: list[Path], wanted: list[str] | None) -> list[Path]:
    """Restrict `exes` to those whose stem appears in `wanted`. None == no filter."""
    if not wanted:
        return exes
    wanted_set = set(wanted)
    return [e for e in exes if e.stem in wanted_set]


def load_aggregated(path: str | Path) -> list[ResultRecord]:
    """Read an `aggregated.json` file and return the list of records."""
    return json.loads(Path(path).read_text())


def resolve_outdir(args: argparse.Namespace) -> Path:
    """Pick the chart output dir. Precedence: `--out` > default (`REPORTS_DIR`, committed)."""
    if args.out:
        return Path(args.out).resolve()
    return REPORTS_DIR
