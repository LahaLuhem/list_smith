"""`cmd_report` — render PNG charts + SUMMARY.md from one aggregated.json.

Default output dir is `benchmark/reports/` (committed, inlined from the package README). `--out`
overrides for ad-hoc snapshots.
"""

from __future__ import annotations

import argparse
import importlib.util
import sys
from pathlib import Path

from list_smith_bench.data.dtos.result_record import flatten_records
from list_smith_bench.data.utils.io import load_aggregated, resolve_outdir


def cmd_report(args: argparse.Namespace) -> int:
    """Generate PNG charts + SUMMARY.md from one aggregated.json file."""
    missing = [
        name
        for name in ("matplotlib", "polars", "seaborn", "pandas")
        if importlib.util.find_spec(name) is None
    ]
    if missing:
        print(f"missing analysis deps: {', '.join(missing)}", file=sys.stderr)
        print("  run `uv sync` from benchmark/python/", file=sys.stderr)
        return 1

    # Local imports keep this module importable without the chart stack.
    import polars as pl

    from list_smith_bench.data.utils import charts, markdown

    records = load_aggregated(args.results)
    if not records:
        print("no records found in input", file=sys.stderr)
        return 1

    out_dir = resolve_outdir(args)
    out_dir.mkdir(parents=True, exist_ok=True)

    dataframe = pl.DataFrame(flatten_records(records), infer_schema_length=None)
    charts.set_default_theme()

    chart_paths: list[Path] = []
    scaling_chart = charts.plot_sync_search_scaling(dataframe, out_dir / "sync_search_scaling.png")
    if scaling_chart is not None:
        chart_paths.append(scaling_chart)

    summary_path = out_dir / "SUMMARY.md"
    summary_path.write_text(
        markdown.render_summary_markdown(dataframe, chart_paths=chart_paths, records=records)
    )

    print(f"\nwrote charts + summary to: {out_dir}")
    for p in chart_paths:
        print(f"  {p.name}")
    print(f"  {summary_path.name}")

    return 0
