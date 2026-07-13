"""Markdown renderer for SUMMARY.md.

The maintainer drops sections from this file into the package README, so the structure is one h2
section per chart with a summary table above and the image embed below. `value_formatter` keeps both
large (43,000 us) and small (390 us) figures readable in one column.
"""

from __future__ import annotations

from collections.abc import Callable
from pathlib import Path

import polars as pl

from list_smith_bench.data.dtos.compare_row import CompareRow
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


def overhead_table(dataframe: pl.DataFrame) -> str:
    """Table of the overhead micros: observer_dispatch + wrapping_overhead by page count."""
    fmt = value_formatter("us")
    rows = ["| Micro | Metric | Median (us) |", "|---|---|---:|"]

    if "microseconds_per_dispatch" in dataframe.columns:
        obs = dataframe.filter(pl.col("microseconds_per_dispatch").is_not_null())
        if not obs.is_empty():
            median = obs.select(pl.col("microseconds_per_dispatch").median()).item()
            rows.append(f"| `observer_dispatch` | us / dispatch | {fmt(median)} |")

    if (
        "microseconds_per_key_computation" in dataframe.columns
        and "page_count" in dataframe.columns
    ):
        wrap = (
            dataframe.filter(pl.col("microseconds_per_key_computation").is_not_null())
            .filter(pl.col("page_count").is_not_null())
            .group_by("page_count")
            .agg(pl.col("microseconds_per_key_computation").median().alias("median"))
            .sort("page_count")
        )
        for row in wrap.iter_rows(named=True):
            plural = "s" if row["page_count"] != 1 else ""
            rows.append(
                f"| `wrapping_overhead` ({row['page_count']} page{plural}) "
                f"| us / key | {fmt(row['median'])} |"
            )

    if len(rows) == 2:
        return "_(no wrapping-overhead micro data in input)_\n"
    return "\n".join(rows) + "\n"


def frame_scenarios_table(dataframe: pl.DataFrame) -> str:
    """Per-frame build cost for the UI scroll/refresh scenarios (scroll pair, cri)."""
    if "avg_frame_build_millis" not in dataframe.columns:
        return "_(no frame-scenario data in input)_\n"

    df = dataframe.filter(pl.col("avg_frame_build_millis").is_not_null())
    if df.is_empty():
        return "_(no frame-scenario data in input)_\n"

    agg = (
        df.group_by("scenario")
        .agg(
            pl.col("frame_count").median().alias("frames"),
            pl.col("avg_frame_build_millis").median().alias("avg"),
            pl.col("worst_frame_build_millis").median().alias("worst"),
            pl.col("p99_frame_build_millis").median().alias("p99"),
            pl.col("missed_frame_build_count").median().alias("missed"),
        )
        .sort("scenario")
    )

    rows = [
        "| Scenario | Frames | Avg build (ms) | Worst build (ms) | p99 build (ms) | Missed |",
        "|---|---:|---:|---:|---:|---:|",
    ]
    for row in agg.iter_rows(named=True):
        rows.append(
            f"| `{row['scenario']}` | {row['frames']:.0f} | {row['avg']:.2f} "
            f"| {row['worst']:.2f} | {row['p99']:.2f} | {row['missed']:.0f} |"
        )
    return "\n".join(rows) + "\n"


def render_latency_table(dataframe: pl.DataFrame) -> str:
    """Median render latency per observer delay for the `slow_observer` scenario (the headline)."""
    metric = "median_render_latency_micros"
    if metric not in dataframe.columns or "observer_delay_millis" not in dataframe.columns:
        return "_(no slow_observer data in input)_\n"

    df = dataframe.filter(pl.col(metric).is_not_null()).filter(
        pl.col("observer_delay_millis").is_not_null()
    )
    if df.is_empty():
        return "_(no slow_observer data in input)_\n"

    agg = (
        df.group_by("observer_delay_millis")
        .agg(
            pl.col(metric).median().alias("median"),
            pl.col("iterations").first().alias("n"),
        )
        .sort("observer_delay_millis")
    )

    rows = [
        "| Observer delay (ms) | Median render latency (ms) | Render minus observer (ms) | N |",
        "|---:|---:|---:|---:|",
    ]
    for row in agg.iter_rows(named=True):
        delay = row["observer_delay_millis"]
        latency_ms = row["median"] / 1000.0
        # Render latency minus the observer's own block: the list_smith render the observer sits on.
        baseline_ms = latency_ms - delay
        rows.append(f"| {delay:.0f} | {latency_ms:,.1f} | {baseline_ms:,.1f} | {row['n']} |")
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
        "## Observer on the critical path: a slow observer blocks rendering\n",
        "The headline finding. `slow_observer` (profile-mode) wires an observer that blocks for "
        "`observer_delay_millis` on each callback and measures render latency over a page load. "
        "list_smith invokes the observer *synchronously* on the page-load path, so the block lands "
        "almost fully on the critical path: a 50 ms observer pushes render latency to ~68 ms "
        "(an ~18 ms baseline render plus the observer's whole 50 ms). Takeaway for consumers: keep "
        "observer callbacks cheap (logging, metrics); push heavy work off the synchronous path.\n",
        render_latency_table(dataframe),
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

    parts.extend(
        [
            "## Wrapping overhead: list_smith on top of ISP\n",
            "Confirms the wrapping costs ~nothing. `observer_dispatch` is one no-op observer "
            "callback (the null-check + virtual call list_smith makes in `_fetchPage`); "
            "`wrapping_overhead` is the per-`getNextPageKey` cost (rebuild the page-item-counts + "
            "run the end policy) as loaded pages grow. Both are dwarfed by any real fetch.\n",
            overhead_table(dataframe),
        ]
    )

    parts.extend(
        [
            "## UI scroll/refresh: per-frame build cost\n",
            "From the profile-mode `integration_test` scenarios (real frames on this machine). "
            "`avg`/`worst`/`p99 build` are the UI-thread build cost per frame (where list_smith's "
            "code runs); `missed` counts frames over the 16.67ms budget. `isp_scroll` vs "
            "`bare_listview` (same items + scroll, no list_smith) is the attribution: the small "
            "delta is what list_smith-over-ISP adds on top of a plain list.\n",
            frame_scenarios_table(dataframe),
        ]
    )

    return "\n".join(parts)


def compare_table(rows: list[CompareRow]) -> str:
    """Markdown Mann-Whitney table, rows sorted by scenario then metric."""
    if not rows:
        return "_(no comparable (scenario, metric) pairs in the two inputs)_\n"

    fmt = value_formatter("us")
    out = [
        "| Scenario | Metric | Baseline median | Current median | Delta | p-value | Sig? |",
        "|---|---|---:|---:|---:|---:|:---:|",
    ]
    for row in sorted(rows, key=lambda r: (r.scenario, r.metric)):
        delta = f"{row.delta_pct:+.1f}%" if row.delta_finite else "n/a"
        sig = "**Yes**" if row.significant else ""
        out.append(
            f"| `{row.scenario}` | `{row.metric}` | {fmt(row.baseline_median)} "
            f"| {fmt(row.current_median)} | {delta} | {row.p_value:.4f} | {sig} |"
        )
    return "\n".join(out) + "\n"


def render_compare_markdown(
    rows: list[CompareRow],
    *,
    chart_paths: list[Path],
    baseline_records: list[ResultRecord],
    current_records: list[ResultRecord],
) -> str:
    """Render COMPARE.md — a forest chart plus the Mann-Whitney significance table.

    Same drop-into-README shape as SUMMARY.md, with both captures' metadata in the header so the
    reader can confirm the comparison is apples to apples (same machine, same SDK).
    """
    base_meta = summary_metadata(baseline_records)
    curr_meta = summary_metadata(current_records)
    chart_names = {p.name for p in chart_paths}

    parts: list[str] = [
        "# Benchmark comparison\n",
        f"- **Baseline**: `{base_meta['package_version']}` at `{base_meta['git_sha']}` "
        f"(Dart SDK {base_meta['sdk_version']}) captured {base_meta['date']}, "
        f"N={base_meta['iterations']} per scenario\n"
        f"- **Current**: `{curr_meta['package_version']}` at `{curr_meta['git_sha']}` "
        f"(Dart SDK {curr_meta['sdk_version']}) captured {curr_meta['date']}, "
        f"N={curr_meta['iterations']} per scenario\n",
        "> Per-machine measurement. Both sides must come from the same machine in the same "
        "thermal/power state with no competing workload, or the delta is noise, not signal.\n",
        "## Forest: every comparable (scenario, metric) delta\n",
        "Bars sorted by `|delta|` (largest at top). Multi-size scenarios are split per pivot "
        "(`sync_filter[list_size=100000]`, ...) so a regression at one size is not masked by "
        "pooling. Colour encodes direction and significance: red = significant regression "
        "(p < 0.05, current higher), green = significant improvement, gray = no significant "
        "difference.\n",
    ]

    if "compare_forest.png" in chart_names:
        parts.append("\n![Forest plot](compare_forest.png)\n")

    parts.extend(
        [
            "## Mann-Whitney U significance table\n",
            "Each row is one `(scenario, metric)` group present in both runs. `Delta` is "
            "`(current - baseline) / baseline * 100` on the medians. `Sig?` flags `p < 0.05`.\n",
            compare_table(rows),
        ]
    )

    return "\n".join(parts)
