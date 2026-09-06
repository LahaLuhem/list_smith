"""Tests for `list_smith_bench.data.utils.meta`'s report-header metadata.

The capture date is the load-bearing bit: SUMMARY.md says "Captured <date>", and re-rendering an
old capture has to reproduce that date rather than stamp it with today, or a committed report
silently claims numbers were measured on whatever day someone last ran `report`.
"""

from __future__ import annotations

from datetime import UTC, datetime

from list_smith_bench.data.utils.meta import summary_metadata

TODAY = datetime.now(UTC).strftime("%Y-%m-%d")


def _record(started_at: str | None, **extra: object) -> dict[str, object]:
    record: dict[str, object] = {"scenario": "s", "iteration": 0, **extra}
    if started_at is not None:
        record["started_at"] = started_at

    return record


class TestCaptureDate:
    def test_reads_the_date_off_started_at_not_the_clock(self) -> None:
        records = [_record("2026-07-18T09:14:02.000Z"), _record("2026-07-18T09:31:55.000Z")]

        assert summary_metadata(records)["date"] == "2026-07-18"

    def test_takes_the_earliest_when_a_run_straddles_midnight(self) -> None:
        records = [_record("2026-07-19T00:04:00+00:00"), _record("2026-07-18T23:58:00+00:00")]

        assert summary_metadata(records)["date"] == "2026-07-18"

    def test_falls_back_to_today_when_no_stamp_parses(self) -> None:
        records = [_record(None), _record("not-a-timestamp"), _record(started_at=None)]

        assert summary_metadata(records)["date"] == TODAY

    def test_skips_unparseable_stamps_rather_than_failing(self) -> None:
        records = [_record("garbage"), _record("2026-07-18T09:14:02.000Z")]

        assert summary_metadata(records)["date"] == "2026-07-18"

    def test_empty_records_fall_back_to_today(self) -> None:
        assert summary_metadata([])["date"] == TODAY


class TestPassthroughFields:
    def test_takes_git_sha_version_and_sdk_from_the_first_record(self) -> None:
        records = [
            _record(
                "2026-07-18T09:14:02.000Z",
                git_sha="63b7319",
                package_version="0.0.1",
                sdk_version="3.12.2",
            ),
        ]
        metadata = summary_metadata(records)

        assert (metadata["git_sha"], metadata["package_version"], metadata["sdk_version"]) == (
            "63b7319",
            "0.0.1",
            "3.12.2",
        )

    def test_unknown_when_a_field_is_absent(self) -> None:
        metadata = summary_metadata([_record("2026-07-18T09:14:02.000Z")])

        assert metadata["git_sha"] == "unknown"
