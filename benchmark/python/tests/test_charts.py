"""Tests for `list_smith_bench.data.utils.charts`."""

from __future__ import annotations

from collections.abc import Callable
from pathlib import Path

import polars as pl
import pytest

from list_smith_bench.data.utils import charts

_FRAME_SCENARIOS = ["isp_scroll", "isp_scroll", "cri_refresh", "cri_refresh"]
_FRAME_PLATFORMS = ["Android", "iOS", "Android", "iOS"]


class TestReportCharts:
    @pytest.mark.parametrize(
        ("plot", "columns"),
        [
            pytest.param(
                charts.plot_sync_search_scaling,
                {
                    "scenario": ["sync_search_scaling"] * 2,
                    "list_size": [1_000, 10_000],
                    "microseconds_per_resolve": [10.0, 100.0],
                },
                id="sync_search_scaling",
            ),
            pytest.param(
                charts.plot_bucket_by_group_scaling,
                {
                    "scenario": ["bucket_by_group_scaling"] * 2,
                    "list_size": [1_000, 10_000],
                    "microseconds_per_bucket": [10.0, 100.0],
                },
                id="bucket_by_group_scaling",
            ),
            pytest.param(
                charts.plot_dedup_scaling,
                {
                    "scenario": ["dedup_scaling"] * 2,
                    "item_count": [1_000, 10_000],
                    "microseconds_per_dedup": [10.0, 100.0],
                },
                id="dedup_scaling",
            ),
            pytest.param(
                charts.plot_frame_costs,
                {
                    "scenario": _FRAME_SCENARIOS,
                    "platform": _FRAME_PLATFORMS,
                    "avg_frame_build_millis": [0.4, 0.3, 0.2, 0.2],
                    "p99_frame_build_millis": [1.0, 0.8, 0.6, 0.5],
                },
                id="frame_costs",
            ),
            pytest.param(
                charts.plot_frame_raster_costs,
                {
                    "scenario": _FRAME_SCENARIOS,
                    "platform": _FRAME_PLATFORMS,
                    "avg_frame_raster_millis": [0.9, 0.8, 0.5, 0.4],
                    "p99_frame_raster_millis": [2.0, 1.8, 1.2, 1.0],
                },
                id="frame_raster_costs",
            ),
            pytest.param(
                charts.plot_observer_latency,
                {
                    "scenario": ["slow_observer"] * 4,
                    "platform": ["Android", "Android", "iOS", "iOS"],
                    "observer_delay_millis": [0, 50, 0, 50],
                    "median_render_latency_micros": [20_000.0, 71_000.0, 18_000.0, 69_000.0],
                },
                id="observer_latency",
            ),
        ],
    )
    def test_renders_from_the_polars_frame_report_builds(
        self,
        plot: Callable[[pl.DataFrame, Path], Path | None],
        columns: dict[str, list[object]],
        tmp_path: Path,
    ) -> None:
        out_path = tmp_path / "chart.png"

        assert plot(pl.DataFrame(columns), out_path) == out_path
        assert out_path.stat().st_size > 0
