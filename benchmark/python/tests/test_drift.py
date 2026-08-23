"""Tests for `list_smith_bench.data.utils.drift`.

`side_timing_separation` is the direct measurement of issue #43's cause: it reports how far apart in
time the two sides were sampled, so a fixed-order run is distinguishable from an interleaved one
without waiting to catch a flake in the act.
"""

from __future__ import annotations

from list_smith_bench.data.dtos.result_record import ResultRecord
from list_smith_bench.data.utils.drift import side_timing_separation


def _at(second: int, *, started_at: bool = True) -> ResultRecord:
    """A record stamped `second` seconds into the job; `started_at=False` omits the stamp."""
    record: ResultRecord = {"scenario": "s", "iteration": 0, "samples": {}, "summary": {}}
    if started_at:
        record["started_at"] = f"2026-01-01T00:00:{second:02d}+00:00"

    return record


class TestSideTimingSeparation:
    def test_blocked_sides_separate_by_about_half_the_job(self) -> None:
        """Today's order: candidate block first, baseline block second."""
        candidate = [_at(s) for s in range(0, 10)]
        baseline = [_at(s) for s in range(10, 20)]

        assert side_timing_separation(baseline, candidate) > 0.45

    def test_interleaved_sides_barely_separate(self) -> None:
        candidate = [_at(s) for s in range(0, 20, 2)]
        baseline = [_at(s) for s in range(1, 20, 2)]

        assert side_timing_separation(baseline, candidate) < 0.10

    def test_missing_timestamps_report_nothing(self) -> None:
        stamped = [_at(1)]
        unstamped = [_at(2, started_at=False)]

        assert side_timing_separation(stamped, unstamped) == 0.0
        assert side_timing_separation(unstamped, stamped) == 0.0

    def test_unparseable_timestamp_is_skipped(self) -> None:
        bad: ResultRecord = {"scenario": "s", "iteration": 0, "samples": {}, "summary": {}}
        bad["started_at"] = "not-a-timestamp"

        assert side_timing_separation([bad], [_at(1)]) == 0.0

    def test_instantaneous_job_reports_nothing(self) -> None:
        """A zero-length span has no fraction to report, and must not divide by zero."""
        assert side_timing_separation([_at(5)], [_at(5)]) == 0.0
