"""How small a regression the gate still catches, and how much noise blinds it.

`test_gate_ordering.py` pins which samples pair with which. This pins the detection floor, which is
what the measurement window and the iteration count move.

The two sides carry different jitter on purpose: one shared pattern separates them completely at any
effect size, so every case would pass and nothing would be pinned.
"""

from __future__ import annotations

import math

import pytest

from list_smith_bench.config import REGRESSION_THRESHOLD_PCT
from list_smith_bench.data.dtos.result_record import ResultRecord
from list_smith_bench.data.utils.stats import (
    compute_compare_rows,
    p_value_floor,
    regressions,
)

# Hardcoded rather than seeded, so a Python RNG change can't move the test.
_BASELINE_JITTER: tuple[float, ...] = (
    1.000, 0.994, 1.012, 0.988, 1.006, 1.017, 0.991, 1.003, 0.985, 1.009,
)  # fmt: skip
_CANDIDATE_JITTER: tuple[float, ...] = (
    0.996, 1.014, 0.987, 1.008, 1.001, 0.990, 1.016, 0.993, 1.011, 0.998,
)  # fmt: skip

_BASE_MICROS = 380.0
# Within-side variation measured on `sync_search_scaling` at n=1000.
_TODAYS_CV_PCT = 1.35


def _coefficient_of_variation(values: tuple[float, ...]) -> float:
    """Sample standard deviation over the median, as a percent. Mirrors the one in `stats`."""
    count = len(values)
    mean = sum(values) / count
    variance = sum((value - mean) ** 2 for value in values) / (count - 1)
    ordered = sorted(values)
    centre = (
        ordered[count // 2] if count % 2 else (ordered[count // 2 - 1] + ordered[count // 2]) / 2.0
    )

    return math.sqrt(variance) / abs(centre) * 100.0


def _scaled(pattern: tuple[float, ...], cv_pct: float) -> tuple[float, ...]:
    """`pattern` stretched about 1.0 until its coefficient of variation is `cv_pct`."""
    mean = sum(pattern) / len(pattern)
    factor = cv_pct / _coefficient_of_variation(pattern)

    return tuple(1.0 + (value - mean) * factor for value in pattern)


def _record(value: float) -> ResultRecord:
    return {
        "scenario": "sync_search_scaling",
        "iteration": 0,
        "samples": {"microseconds_per_resolve": [value]},
        "summary": {"list_size": 1000},
    }


def _sides(
    *,
    cv_pct: float,
    effect_pct: float,
    samples_per_side: int = 10,
) -> tuple[list[ResultRecord], list[ResultRecord]]:
    """Both sides at a given within-side noise, the candidate `effect_pct` genuinely slower."""
    baseline_jitter = _scaled(_BASELINE_JITTER, cv_pct)[:samples_per_side]
    candidate_jitter = _scaled(_CANDIDATE_JITTER, cv_pct)[:samples_per_side]
    slowdown = 1.0 + effect_pct / 100.0

    return (
        [_record(_BASE_MICROS * jitter) for jitter in baseline_jitter],
        [_record(_BASE_MICROS * jitter * slowdown) for jitter in candidate_jitter],
    )


def _trips(**kwargs: float | int) -> bool:
    baseline, candidate = _sides(**kwargs)  # type: ignore[arg-type]

    return bool(regressions(compute_compare_rows(baseline, candidate), REGRESSION_THRESHOLD_PCT))


class TestDetectionAtTodaysNoise:
    """At the noise the suite actually runs at, the 10% threshold is what decides."""

    @pytest.mark.parametrize("effect_pct", [10.5, 12.0, 15.0, 20.0])
    def test_catches_a_regression_past_the_threshold(self, effect_pct: float) -> None:
        assert _trips(cv_pct=_TODAYS_CV_PCT, effect_pct=effect_pct)

    @pytest.mark.parametrize("effect_pct", [0.0, 5.0, 8.0, 9.5])
    def test_ignores_a_shift_under_the_threshold(self, effect_pct: float) -> None:
        assert not _trips(cv_pct=_TODAYS_CV_PCT, effect_pct=effect_pct)

    def test_p_is_already_at_its_floor_so_only_the_threshold_moves(self) -> None:
        rows = compute_compare_rows(*_sides(cv_pct=_TODAYS_CV_PCT, effect_pct=5.0))

        assert rows[0].p_value == pytest.approx(p_value_floor(10, 10))


class TestNoiseTolerance:
    """How much within-side variation the gate absorbs before a real regression goes unseen.

    The guard on the measurement window: shortening it buys wall clock and pays in variance.
    """

    @pytest.mark.parametrize("cv_pct", [1.0, 2.0, 4.0, 8.0, 12.0])
    def test_a_real_regression_survives_inflated_noise(self, cv_pct: float) -> None:
        assert _trips(cv_pct=cv_pct, effect_pct=15.0)

    def test_the_gate_goes_blind_once_noise_reaches_the_effect_size(self) -> None:
        """At 15% CV against a 15% regression, the sides overlap enough that p clears 0.05."""
        assert not _trips(cv_pct=15.0, effect_pct=15.0)

    def test_headroom_over_todays_noise_is_about_nine_fold(self) -> None:
        assert _TODAYS_CV_PCT * 8 < 12.0
        assert not _trips(cv_pct=_TODAYS_CV_PCT * 12, effect_pct=15.0)


class TestSampleCountFloor:
    """Mann-Whitney cannot reach p < 0.05 below four samples a side, whatever the effect size."""

    @pytest.mark.parametrize("samples_per_side", [2, 3])
    def test_too_few_samples_cannot_trip_the_gate_at_all(self, samples_per_side: int) -> None:
        assert p_value_floor(samples_per_side, samples_per_side) >= 0.05
        assert not _trips(cv_pct=_TODAYS_CV_PCT, effect_pct=50.0, samples_per_side=samples_per_side)

    @pytest.mark.parametrize("samples_per_side", [4, 5, 6, 8, 10])
    def test_four_a_side_is_the_structural_minimum(self, samples_per_side: int) -> None:
        assert p_value_floor(samples_per_side, samples_per_side) < 0.05
        assert _trips(cv_pct=_TODAYS_CV_PCT, effect_pct=15.0, samples_per_side=samples_per_side)
