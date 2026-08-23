"""Ordering sensitivity of the regression gate (issue #43).

`test_stats.py` covers *whether* two sample sets differ. This file pins *which samples pair with
which*, which is what the fixed candidate-then-baseline run order gets wrong: the sides are ranked
against each other while the machine drifts underneath them, so drift over the job reads as a
one-sided effect.

Samples are synthetic but shaped like the real thing (about 1.1% CV, against 1.35% measured on
`sync_search_scaling` at n=1000), so these stay deterministic and machine-independent while still
running the real `compute_compare_rows` / `regressions`.
"""

from __future__ import annotations

import pytest

from list_smith_bench.config import REGRESSION_THRESHOLD_PCT
from list_smith_bench.data.dtos.result_record import ResultRecord
from list_smith_bench.data.utils.stats import compute_compare_rows, regressions

# One run's jitter, hardcoded rather than seeded so a Python RNG change can't move the test. Ten
# samples per side: DEFAULT_ITERATIONS, one process each once interleaved.
_JITTER: tuple[float, ...] = (1.000, 0.994, 1.012, 0.988, 1.006, 1.017, 0.991, 1.003, 0.985, 1.009)
_BASE_MICROS = 380.0
# Per-process level lottery. `wrapping_overhead[page_count=100]` is allocation-throughput bound, so
# whatever the VM settles on at process start (new-space sizing, core assignment) fixes that
# process's level for its whole life: flat within a block, disjoint between blocks. Measured live on
# PR #50 at +22.3% between two byte-identical binaries; the first two entries reproduce that draw.
_PROCESS_LEVELS: tuple[float, ...] = (
    1.22,
    1.00,
    1.05,
    1.18,
    0.96,
    1.12,
    1.15,
    0.98,
    1.08,
    1.02,
    1.10,
    1.06,
    0.99,
    1.14,
    1.04,
    1.01,
    1.16,
    1.07,
    1.03,
    1.09,
)


def _record(value: float) -> ResultRecord:
    return {
        "scenario": "sync_search_scaling",
        "iteration": 0,
        "samples": {"microseconds_per_resolve": [value]},
        "summary": {"list_size": 1000},
    }


def _sides(
    ramp: float,
    *,
    interleaved: bool,
    candidate_factor: float = 1.0,
) -> tuple[list[ResultRecord], list[ResultRecord]]:
    """Both sides as measured on a machine that gets `ramp` faster from job start to job end.

    Each measurement sits at position `t` in the job, 0.0 first to 1.0 last, and costs
    `1 + ramp * (1 - t)`. Fixed order puts the whole candidate block in the first (slowest) half;
    interleaving alternates the sides so both span the same drift. `candidate_factor` is a genuine
    regression in the candidate binary, present whatever the ordering.
    """
    count = len(_JITTER)
    last = 2 * count - 1
    baseline: list[ResultRecord] = []
    candidate: list[ResultRecord] = []
    for index, jitter in enumerate(_JITTER):
        if interleaved:
            t_candidate, t_baseline = (2 * index) / last, (2 * index + 1) / last
        else:
            t_candidate, t_baseline = index / last, (count + index) / last
        candidate.append(
            _record(_BASE_MICROS * jitter * candidate_factor * (1 + ramp * (1 - t_candidate)))
        )
        baseline.append(_record(_BASE_MICROS * jitter * (1 + ramp * (1 - t_baseline))))

    return baseline, candidate


def _stepped_sides(
    *,
    interleaved: bool,
    candidate_factor: float = 1.0,
) -> tuple[list[ResultRecord], list[ResultRecord]]:
    """Both sides when each process settles at its own level, rather than the machine drifting.

    One micro is one process per side, so fixed order gives each side a single draw from
    `_PROCESS_LEVELS` and inherits it for all ten samples. Interleaving alternates *processes*, so
    each side draws ten and the lottery averages out. That granularity is the point: interleaving at
    the micro level instead would leave each side on one draw and fix nothing.
    """
    baseline: list[ResultRecord] = []
    candidate: list[ResultRecord] = []
    for index, jitter in enumerate(_JITTER):
        if interleaved:
            level_candidate = _PROCESS_LEVELS[2 * index]
            level_baseline = _PROCESS_LEVELS[2 * index + 1]
        else:
            level_candidate, level_baseline = _PROCESS_LEVELS[0], _PROCESS_LEVELS[1]
        candidate.append(_record(_BASE_MICROS * jitter * candidate_factor * level_candidate))
        baseline.append(_record(_BASE_MICROS * jitter * level_baseline))

    return baseline, candidate


def _trips(baseline: list[ResultRecord], candidate: list[ResultRecord]) -> bool:
    return bool(regressions(compute_compare_rows(baseline, candidate), REGRESSION_THRESHOLD_PCT))


class TestDriftAlone:
    """No real regression: identical code on both sides, only the machine moving underneath."""

    # Measured crossover in this model: fixed order clears the 10% gate at ~20% job drift, so the
    # cases below sit clear of that edge. Interleaved peaks at +2.5% even at 60% drift.

    @pytest.mark.parametrize("ramp", [0.25, 0.30, 0.50])
    def test_fixed_order_trips_on_drift_alone(self, ramp: float) -> None:
        assert _trips(*_sides(ramp, interleaved=False))

    @pytest.mark.parametrize("ramp", [0.25, 0.30, 0.50, 0.60])
    def test_interleaving_absorbs_the_same_drift(self, ramp: float) -> None:
        assert not _trips(*_sides(ramp, interleaved=True))

    def test_a_quiet_machine_trips_under_neither_ordering(self) -> None:
        assert not _trips(*_sides(0.0, interleaved=False))
        assert not _trips(*_sides(0.0, interleaved=True))


class TestSensitivityIsRetained:
    """Interleaving must only remove the drift, never the ability to see a real regression."""

    @pytest.mark.parametrize("ramp", [0.0, 0.20, 0.30, 0.50])
    def test_interleaving_still_catches_a_real_regression(self, ramp: float) -> None:
        assert _trips(*_sides(ramp, interleaved=True, candidate_factor=1.15))

    def test_fixed_order_overstates_a_real_regression_under_drift(self) -> None:
        """Drift inflates the reported delta, so today's numbers overstate severity too."""
        fixed = compute_compare_rows(*_sides(0.30, interleaved=False, candidate_factor=1.15))
        interleaved = compute_compare_rows(*_sides(0.30, interleaved=True, candidate_factor=1.15))

        assert fixed[0].delta_pct > interleaved[0].delta_pct + 10.0


class TestOnlyTheThresholdDecides:
    def test_p_value_saturates_well_below_the_gate(self) -> None:
        """A flat offset pins p to its floor from ~5% on, so p cannot separate 5% from 22%."""
        p_values = set()
        for offset in (0.05, 0.11, 0.22):
            rows = compute_compare_rows(
                *_sides(0.0, interleaved=False, candidate_factor=1 + offset)
            )
            p_values.add(round(rows[0].p_value, 9))

        assert len(p_values) == 1


class TestPerProcessSteps:
    """The shape CI actually produced (PR #50), as opposed to a smooth ramp.

    Both sides compiled byte-identical binaries and the gate still reported +22.3%, with the two
    sides' sample distributions completely disjoint and each side flat internally.
    """

    def test_fixed_order_trips_on_one_unlucky_process(self) -> None:
        assert _trips(*_stepped_sides(interleaved=False))

    def test_interleaving_averages_the_process_lottery_away(self) -> None:
        assert not _trips(*_stepped_sides(interleaved=True))

    def test_interleaving_still_catches_a_real_regression_through_the_lottery(self) -> None:
        assert _trips(*_stepped_sides(interleaved=True, candidate_factor=1.15))
