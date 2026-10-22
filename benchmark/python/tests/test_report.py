"""Tests for `list_smith_bench.subcommands.report`."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from list_smith_bench.subcommands.report import cmd_report


def _frame_record(platform: str) -> dict[str, object]:
    return {
        "scenario": "isp_scroll",
        "iteration": 0,
        "iterations": 10,
        "platform": platform,
        "sdk_version": "3.13.4",
        "package_version": "1.0.0",
        "git_sha": "a1b2c3d",
        "started_at": "2026-10-22T10:00:00Z",
        "samples": {"frame_build_micros": [400], "frame_raster_micros": [900]},
        "summary": {
            "avg_frame_build_millis": 0.4,
            "worst_frame_build_millis": 2.0,
            "p99_frame_build_millis": 1.0,
            "missed_frame_build_count": 0,
            "avg_frame_raster_millis": 0.9,
            "worst_frame_raster_millis": 3.0,
            "p99_frame_raster_millis": 2.0,
            "missed_frame_raster_count": 0,
            "frame_count": 610,
        },
    }


class TestPerPlatformReport:
    def test_one_file_per_platform_reports_each_platform(self, tmp_path: Path) -> None:
        results = []
        for platform in ("android", "ios"):
            path = tmp_path / f"{platform}.json"
            path.write_text(json.dumps([_frame_record(platform)]))
            results.append(str(path))
        out = tmp_path / "report"

        assert cmd_report(argparse.Namespace(results=results, out=str(out))) == 0

        summary = (out / "SUMMARY.md").read_text()
        assert "| `isp_scroll` | Android |" in summary
        assert "| `isp_scroll` | iOS |" in summary
        assert (out / "frame_costs.png").stat().st_size > 0
