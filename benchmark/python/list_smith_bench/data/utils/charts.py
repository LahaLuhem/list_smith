"""Chart renderers.

Module-level matplotlib/polars/seaborn/pandas imports are intentional — this module only makes
sense with the analysis stack installed. Subcommands gate the call site with a `find_spec` check so
the import error points users at `uv sync`.

Each plot fn returns the `Path` it wrote (threaded into a chart-paths list), or `None` when it has
no data so the caller can skip the slot in markdown.
"""

from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd
import polars as pl
import seaborn as sns

from list_smith_bench.config import (
    CHART_DPI,
    CHART_PALETTE,
    FOREST_COLOUR_IMPROVEMENT,
    FOREST_COLOUR_NOT_SIG,
    FOREST_COLOUR_REGRESSION,
    FRAME_BUDGET_MICROS_60HZ,
)
from list_smith_bench.data.dtos.compare_row import CompareRow


def set_default_theme() -> None:
    """Apply the shared seaborn theme. Idempotent; the subcommand calls it once at start."""
    sns.set_theme(style="whitegrid", context="paper", palette=CHART_PALETTE)


def write_empty_chart(out_path: Path, message: str) -> None:
    """Render a 'no data' placeholder PNG so markdown image refs stay valid."""
    fig, ax = plt.subplots(figsize=(8, 4))
    ax.text(0.5, 0.5, message, ha="center", va="center", fontsize=12, color="#888")
    ax.set_axis_off()
    fig.savefig(out_path, dpi=CHART_DPI)
    plt.close(fig)


def plot_sync_search_scaling(dataframe: pl.DataFrame, out_path: Path) -> Path | None:
    """Line plot of `microseconds_per_resolve` vs `list_size`, with the 60 Hz frame budget marked.

    From the `sync_search_scaling` micro (choke point #2): the synchronous cost of filtering an
    in-memory list on each committed query. Where the line crosses the frame-budget rule is the
    practical ceiling for sync search with the measured predicate.

    Returns None (writes nothing) when the input has no `sync_search_scaling` data.
    """
    metric = "microseconds_per_resolve"
    if metric not in dataframe.columns or "list_size" not in dataframe.columns:
        return None

    plot_df = (
        dataframe.filter(pl.col("scenario") == "sync_search_scaling")
        .filter(pl.col(metric).is_not_null())
        .filter(pl.col("list_size").is_not_null())
        .select(["list_size", metric])
        .to_pandas()
    )
    if plot_df.empty:
        return None

    fig, ax = plt.subplots(figsize=(8, 5))
    sns.pointplot(
        data=plot_df,
        x="list_size",
        y=metric,
        ax=ax,
        errorbar=("pi", 50),
        marker="o",
        linestyle="-",
        color="#4c72b0",
    )
    ax.axhline(
        FRAME_BUDGET_MICROS_60HZ,
        color="#c0392b",
        linestyle="--",
        linewidth=1.0,
        label="60 Hz frame budget (16.67 ms)",
    )
    ax.set_xlabel("In-memory list size (items)")
    ax.set_ylabel("resolveSyncSearch cost (us)")
    ax.set_title("Sync-search filter cost scales linearly with list size")
    ax.legend(loc="best")
    plt.tight_layout()
    fig.savefig(out_path, dpi=CHART_DPI)
    plt.close(fig)
    return out_path


# ---- compare charts (two datasets) ----------------------------------------


def plot_compare_forest(rows: list[CompareRow], out_path: Path) -> Path:
    """Horizontal bar chart of % delta per (scenario, metric), sorted by |delta|.

    Lower is better for every metric here (microseconds/op, per-frame build cost), so the colour
    encoding reads directly: red = significant regression (current higher), green = significant
    improvement (current lower), gray = no significant difference. The zero line is "no change".
    """
    plot_rows = [row for row in rows if row.delta_finite]
    if not plot_rows:
        write_empty_chart(out_path, "No comparable (scenario, metric) pairs.")
        return out_path

    # Ascending by |delta| so the biggest bar lands at the top (barh renders row 0 at bottom).
    plot_rows = sorted(plot_rows, key=lambda row: abs(row.delta_pct))

    labels = [f"{row.scenario} / {row.metric}" for row in plot_rows]
    deltas = [row.delta_pct for row in plot_rows]
    colours = [_forest_colour(row) for row in plot_rows]

    # Height scales with row count so bars stay readable from a handful to dozens of rows.
    height = max(4.0, len(plot_rows) * 0.3)
    fig, ax = plt.subplots(figsize=(10, height))
    ax.barh(labels, deltas, color=colours, edgecolor="#555", linewidth=0.5)
    ax.axvline(0, color="#333", linewidth=0.8)
    ax.set_xlabel("Delta from baseline (%)")
    ax.set_title("Per-(scenario, metric) delta (red=regression, green=improvement, gray=not sig)")
    ax.grid(True, axis="x", alpha=0.3)
    plt.tight_layout()
    fig.savefig(out_path, dpi=CHART_DPI)
    plt.close(fig)
    return out_path


def _forest_colour(row: CompareRow) -> str:
    """The forest-bar colour for one row: gray if not significant, else red/green by direction."""
    if not row.significant:
        return FOREST_COLOUR_NOT_SIG
    return FOREST_COLOUR_REGRESSION if row.delta_pct > 0 else FOREST_COLOUR_IMPROVEMENT


# `pd` is imported at module level so pandas is available when polars hands frames to seaborn via
# `.to_pandas()` (which uses pyarrow under the hood). Reference it to suppress the unused warning.
_ = pd
