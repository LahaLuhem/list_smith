"""Tests for `list_smith_bench.data.utils.stats`.

Pure, deterministic math — the highest-value regression target in the analyzer. Covers `median`,
`group_samples`, and `compute_compare_rows`, including the pivot-aware grouping that splits
multi-size scenarios (`list_size` / `page_count`) so a regression at one size is not masked by
pooling, and the tie guard (older scipy raises, newer returns nan; both must land on p=1.0).
"""

from __future__ import annotations

import math

import pytest

from list_smith_bench.data.dtos.result_record import ResultRecord
from list_smith_bench.data.utils.stats import (
    compute_compare_rows,
    group_samples,
    median,
    regressions,
)


def _record(
    scenario: str,
    samples: dict[str, object],
    summary: dict[str, object] | None = None,
) -> ResultRecord:
    """A minimal result record: scenario + raw samples, plus an optional summary (for pivots)."""
    return {"scenario": scenario, "iteration": 0, "samples": samples, "summary": summary or {}}


class TestMedian:
    def test_empty_returns_zero(self) -> None:
        assert median([]) == 0.0

    def test_single_value(self) -> None:
        assert median([42.0]) == 42.0

    def test_odd_count(self) -> None:
        assert median([3.0, 1.0, 2.0]) == 2.0

    def test_even_count_averages_middle_two(self) -> None:
        assert median([1.0, 2.0, 3.0, 4.0]) == 2.5

    def test_floats(self) -> None:
        assert median([0.1, 0.2, 0.3]) == pytest.approx(0.2)


class TestGroupSamples:
    def test_empty_returns_empty(self) -> None:
        assert group_samples([]) == {}

    def test_concatenates_samples_across_records(self) -> None:
        records = [
            _record("sync_filter", {"microseconds_per_commit": [9.0, 9.1]}),
            _record("sync_filter", {"microseconds_per_commit": [9.2]}),
        ]
        groups = group_samples(records)
        assert groups == {("sync_filter", "microseconds_per_commit"): [9.0, 9.1, 9.2]}

    def test_non_list_sample_value_skipped(self) -> None:
        records = [_record("weird", {"x": "not a list"})]
        assert group_samples(records) == {}

    def test_non_numeric_values_filtered(self) -> None:
        records = [_record("weird", {"x": [1, 2, "three", 4]})]
        assert group_samples(records) == {("weird", "x"): [1.0, 2.0, 4.0]}


class TestComputeCompareRows:
    def test_empty_inputs_return_empty(self) -> None:
        assert compute_compare_rows([], []) == []

    def test_shared_key_produces_one_row(self) -> None:
        baseline = [_record("a", {"m": [1.0, 2.0, 3.0]})]
        current = [_record("a", {"m": [1.0, 2.0, 3.0]})]
        rows = compute_compare_rows(baseline, current)
        assert [(row.scenario, row.metric) for row in rows] == [("a", "m")]

    def test_keys_only_in_one_run_are_skipped(self) -> None:
        baseline = [_record("a", {"m1": [1.0, 2.0, 3.0]})]
        current = [_record("a", {"m2": [4.0, 5.0, 6.0]})]
        assert compute_compare_rows(baseline, current) == []

    def test_identical_samples_not_significant(self) -> None:
        baseline = [_record("a", {"m": [9.0, 9.1, 9.2, 9.3, 9.4]})]
        current = [_record("a", {"m": [9.0, 9.1, 9.2, 9.3, 9.4]})]
        row = compute_compare_rows(baseline, current)[0]
        assert row.delta_pct == 0.0
        assert not row.significant

    def test_separated_samples_flag_significant_regression(self) -> None:
        baseline = [_record("a", {"m": [14.0, 14.1, 14.2, 14.3, 14.4]})]
        current = [_record("a", {"m": [20.0, 20.1, 20.2, 20.3, 20.4]})]
        row = compute_compare_rows(baseline, current)[0]
        assert row.significant
        assert row.delta_pct > 0
        assert row.current_median > row.baseline_median

    def test_zero_baseline_yields_infinite_delta(self) -> None:
        baseline = [_record("a", {"m": [0.0, 0.0, 0.0]})]
        current = [_record("a", {"m": [1.0, 2.0, 3.0]})]
        row = compute_compare_rows(baseline, current)[0]
        assert math.isinf(row.delta_pct)
        assert not row.delta_finite

    def test_constant_samples_coerced_to_p_one(self) -> None:
        # All-identical input: newer scipy returns nan, older raises; both must land on p=1.0.
        baseline = [_record("a", {"m": [5.0, 5.0, 5.0]})]
        current = [_record("a", {"m": [5.0, 5.0, 5.0]})]
        row = compute_compare_rows(baseline, current)[0]
        assert row.p_value == 1.0
        assert not row.significant

    def test_mannwhitneyu_value_error_coerced_to_p_one(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        # Force the old-scipy raise path; the guard must absorb it as "no difference", not blow up.
        import scipy.stats

        def boom(*_args: object, **_kwargs: object) -> object:
            raise ValueError("mocked: mannwhitneyu refused these samples")

        monkeypatch.setattr(scipy.stats, "mannwhitneyu", boom)
        baseline = [_record("a", {"m": [1.0, 2.0, 3.0]})]
        current = [_record("a", {"m": [4.0, 5.0, 6.0]})]
        row = compute_compare_rows(baseline, current)[0]
        assert row.p_value == 1.0
        assert not row.significant


class TestPivotAwareGrouping:
    def test_list_size_splits_into_per_size_rows(self) -> None:
        # A regression at one size must surface in its own row, not be masked by pooling all sizes
        # into one bi/tri-modal distribution. That isolation is the whole point of the pivot split.
        scenario = "sync_search_scaling"
        baseline = [
            _record(scenario, {"m": [9.0, 9.1, 9.2, 9.3, 9.4]}, {"list_size": 1000}),
            _record(scenario, {"m": [14.0, 14.1, 14.2, 14.3, 14.4]}, {"list_size": 100000}),
        ]
        current = [
            _record(scenario, {"m": [9.0, 9.1, 9.2, 9.3, 9.4]}, {"list_size": 1000}),
            _record(scenario, {"m": [20.0, 20.1, 20.2, 20.3, 20.4]}, {"list_size": 100000}),
        ]
        by_label = {row.scenario: row for row in compute_compare_rows(baseline, current)}
        assert set(by_label) == {f"{scenario}[list_size=1000]", f"{scenario}[list_size=100000]"}
        assert not by_label[f"{scenario}[list_size=1000]"].significant
        big = by_label[f"{scenario}[list_size=100000]"]
        assert big.significant
        assert big.delta_pct > 0

    def test_page_count_pivot_labels_rows(self) -> None:
        baseline = [_record("wrapping_overhead", {"m": [0.5, 0.6, 0.7]}, {"page_count": 10})]
        current = [_record("wrapping_overhead", {"m": [0.5, 0.6, 0.7]}, {"page_count": 10})]
        rows = compute_compare_rows(baseline, current)
        assert [row.scenario for row in rows] == ["wrapping_overhead[page_count=10]"]

    def test_no_pivot_leaves_scenario_unlabelled(self) -> None:
        baseline = [_record("isp_scroll", {"frame_build_micros": [400.0, 410.0, 420.0]})]
        current = [_record("isp_scroll", {"frame_build_micros": [400.0, 410.0, 420.0]})]
        rows = compute_compare_rows(baseline, current)
        assert [row.scenario for row in rows] == ["isp_scroll"]


class TestRegressions:
    def test_unchanged_is_no_regression(self) -> None:
        baseline = [_record("a", {"m": [9.0, 9.1, 9.2, 9.3, 9.4]})]
        current = [_record("a", {"m": [9.0, 9.1, 9.2, 9.3, 9.4]})]
        assert regressions(compute_compare_rows(baseline, current), 10.0) == []

    def test_significant_slowdown_past_threshold_trips(self) -> None:
        baseline = [_record("a", {"m": [14.0, 14.1, 14.2, 14.3, 14.4]})]
        current = [_record("a", {"m": [20.0, 20.1, 20.2, 20.3, 20.4]})]  # +42%, fully separated
        assert len(regressions(compute_compare_rows(baseline, current), 10.0)) == 1

    def test_significant_but_below_threshold_ignored(self) -> None:
        # ~3% slower and significant, but under the 10% gate, so it must not count as a regression.
        baseline = [_record("a", {"m": [100.0, 100.1, 100.2, 100.3, 100.4]})]
        current = [_record("a", {"m": [103.0, 103.1, 103.2, 103.3, 103.4]})]
        assert regressions(compute_compare_rows(baseline, current), 10.0) == []

    def test_improvement_is_not_a_regression(self) -> None:
        baseline = [_record("a", {"m": [20.0, 20.1, 20.2, 20.3, 20.4]})]
        current = [_record("a", {"m": [14.0, 14.1, 14.2, 14.3, 14.4]})]  # faster
        assert regressions(compute_compare_rows(baseline, current), 10.0) == []
