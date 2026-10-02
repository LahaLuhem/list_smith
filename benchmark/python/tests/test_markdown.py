"""Tests for `list_smith_bench.data.utils.markdown`'s SUMMARY.md prose."""

from __future__ import annotations

import polars as pl

from list_smith_bench.data.utils.markdown import render_summary_markdown


def _summary(latency_by_delay: dict[int, float]) -> str:
    dataframe = pl.DataFrame(
        {
            "scenario": ["slow_observer"] * len(latency_by_delay),
            "observer_delay_millis": list(latency_by_delay),
            "median_render_latency_micros": list(latency_by_delay.values()),
            "iterations": [10] * len(latency_by_delay),
        }
    )

    return render_summary_markdown(dataframe, chart_paths=[], records=[])


class TestObserverHeadline:
    def test_its_example_reads_the_capture(self) -> None:
        summary = _summary({0: 20_000, 50: 71_000})

        assert "a 50 ms observer pushes ~21 ms to ~71 ms" in summary

    def test_drops_the_example_without_a_50_ms_capture(self) -> None:
        summary = _summary({0: 20_000, 25: 46_000})

        assert "50 ms observer" not in summary
