"""Tests for `list_smith_bench.data.utils.markdown`'s SUMMARY.md prose."""

from __future__ import annotations

import polars as pl

from list_smith_bench.data.utils.markdown import frame_scenarios_table, render_summary_markdown


def _summary(latency_by_platform: dict[str, dict[int, float]]) -> str:
    rows = [
        (platform, delay, latency)
        for platform, latency_by_delay in latency_by_platform.items()
        for delay, latency in latency_by_delay.items()
    ]
    dataframe = pl.DataFrame(
        {
            "scenario": ["slow_observer"] * len(rows),
            "platform": [platform for platform, _, _ in rows],
            "observer_delay_millis": [delay for _, delay, _ in rows],
            "median_render_latency_micros": [latency for _, _, latency in rows],
            "iterations": [10] * len(rows),
        }
    )

    return render_summary_markdown(dataframe, chart_paths=[], records=[])


class TestObserverHeadline:
    def test_its_example_reads_the_capture(self) -> None:
        summary = _summary({"Android": {0: 20_000, 50: 71_000}})

        assert "a 50 ms observer pushes ~21 ms to ~71 ms" in summary

    def test_drops_the_example_without_a_50_ms_capture(self) -> None:
        summary = _summary({"Android": {0: 20_000, 25: 46_000}})

        assert "50 ms observer" not in summary

    def test_its_example_reads_each_platform(self) -> None:
        summary = _summary(
            {"Android": {0: 20_000, 50: 71_000}, "iOS": {0: 18_000, 50: 69_000}},
        )

        assert "pushes ~21 ms to ~71 ms on Android and ~19 ms to ~69 ms on iOS" in summary


class TestFrameTable:
    def test_has_a_row_per_scenario_and_platform(self) -> None:
        dataframe = pl.DataFrame(
            {
                "scenario": ["isp_scroll", "isp_scroll"],
                "platform": ["Android", "iOS"],
                "frame_count": [610, 610],
                "avg_frame_build_millis": [0.4, 0.3],
                "worst_frame_build_millis": [2.0, 1.5],
                "p99_frame_build_millis": [1.0, 0.8],
                "missed_frame_build_count": [0, 0],
            }
        )

        table = frame_scenarios_table(dataframe, "build")

        assert "| `isp_scroll` | Android |" in table
        assert "| `isp_scroll` | iOS |" in table
