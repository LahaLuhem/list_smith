"""Markdown renderer for SUMMARY.md.

The maintainer drops sections from this file into the package README, so the structure is one h2
section per chart with a summary table above and the image embed below. `value_formatter` keeps both
large (43,000 us) and small (390 us) figures readable in one column.
"""

from __future__ import annotations

from collections.abc import Callable
from pathlib import Path

import polars as pl

from list_smith_bench.data.dtos.result_record import ResultRecord
from list_smith_bench.data.utils.meta import summary_metadata


def value_formatter(units: str) -> Callable[[float | int | None], str]:
    """Return a unary fn formatting a numeric value for the requested units.

    Precision tiers for "us"/freeform: >= 1000 rounds to integers with thousands separators; 1-1000
    gets two decimals; sub-1 gets three.
    """

    def _format_number(value: float | int | None) -> str:
        if value is None:
            return "-"
        abs_value = abs(value)
        if abs_value >= 1000:
            return f"{value:,.0f}"
        if abs_value >= 1:
            return f"{value:,.2f}"
        return f"{value:,.3f}"

    return _format_number


def sync_search_scaling_table(dataframe: pl.DataFrame) -> str:
    """Markdown table of resolve cost per `list_size` for the `sync_search_scaling` micro."""
    metric = "microseconds_per_resolve"
    if metric not in dataframe.columns or "list_size" not in dataframe.columns:
        return "_(no sync_search_scaling data in input)_\n"

    df = dataframe.filter(pl.col(metric).is_not_null()).filter(pl.col("list_size").is_not_null())
    if df.is_empty():
        return "_(no sync_search_scaling data in input)_\n"

    agg = (
        df.group_by("list_size")
        .agg(
            pl.col(metric).count().alias("n"),
            pl.col(metric).median().alias("median"),
            pl.col(metric).quantile(0.25).alias("q25"),
            pl.col(metric).quantile(0.75).alias("q75"),
        )
        .sort("list_size")
    )

    fmt = value_formatter("us")
    rows = [
        "| List size | N | Median (us) | IQR (us) | Median (ms) |",
        "|---:|---:|---:|---:|---:|",
    ]
    for row in agg.iter_rows(named=True):
        iqr = row["q75"] - row["q25"]
        median_ms = row["median"] / 1000.0
        rows.append(
            f"| {row['list_size']:,} | {row['n']} | {fmt(row['median'])} "
            f"| {fmt(iqr)} | {median_ms:,.2f} |"
        )
    return "\n".join(rows) + "\n"


def render_summary_markdown(
    dataframe: pl.DataFrame,
    *,
    chart_paths: list[Path],
    records: list[ResultRecord],
) -> str:
    """Render SUMMARY.md — per-chart sections with a table above each PNG."""
    metadata = summary_metadata(records)
    chart_names = {p.name for p in chart_paths}

    parts: list[str] = [
        "# Benchmark results\n",
        f"Captured **{metadata['date']}** against `{metadata['package_version']}` at "
        f"`{metadata['git_sha']}` on Dart SDK {metadata['sdk_version']}. "
        f"N={metadata['iterations']} iterations.\n",
        "> Per-machine measurements. Numbers reflect *this* machine (CPU, GPU, GC, OS "
        "scheduler, thermal state). Your numbers WILL differ; capture your own local "
        "baseline before measuring a code delta.\n",
        "## Sync-search filter cost vs list size\n",
        "From the `sync_search_scaling` micro (AOT, `benchmark_harness`). `SyncListView` "
        "re-runs `resolveSyncSearch` (an `items.where(predicate).toList()`) synchronously "
        "on every committed query; this measures that cost as the in-memory list grows, "
        "with a naive case-insensitive `contains` predicate. Where the median crosses the "
        "frame budget is the practical ceiling for sync search with this predicate.\n",
        sync_search_scaling_table(dataframe),
    ]

    if "sync_search_scaling.png" in chart_names:
        parts.append("\n![Sync-search scaling](sync_search_scaling.png)\n")

    return "\n".join(parts)
