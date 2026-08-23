"""Tests for `list_smith_bench.subcommands.ab`'s pure scheduling.

The interleaving order is the whole fix for issue #43, so it is pinned here rather than left to a
read of the runner. Everything else in `ab` is subprocess plumbing.
"""

from __future__ import annotations

from list_smith_bench.subcommands.ab import BASELINE, CANDIDATE, interleaved_schedule


class TestInterleavedSchedule:
    def test_neither_side_gets_the_earlier_slots(self) -> None:
        """The property the fix rests on: equal mean position, so drift lands on both equally."""
        sides = [side for _, side in interleaved_schedule(10)]
        mean_position = {
            name: sum(i for i, side in enumerate(sides) if side == name) / sides.count(name)
            for name in (CANDIDATE, BASELINE)
        }

        assert mean_position[CANDIDATE] == mean_position[BASELINE]

    def test_an_odd_count_leaves_at_most_half_a_slot_of_imbalance(self) -> None:
        sides = [side for _, side in interleaved_schedule(5)]
        mean_position = {
            name: sum(i for i, side in enumerate(sides) if side == name) / sides.count(name)
            for name in (CANDIDATE, BASELINE)
        }

        assert abs(mean_position[CANDIDATE] - mean_position[BASELINE]) <= 0.5

    def test_each_side_runs_once_per_iteration(self) -> None:
        schedule = interleaved_schedule(5)

        for iteration in range(5):
            sides = sorted(side for i, side in schedule if i == iteration)
            assert sides == sorted([BASELINE, CANDIDATE])

    def test_the_leader_swaps_each_iteration(self) -> None:
        """A fixed leader would hand the same side the first slot every time."""
        leaders = [
            next(side for i, side in interleaved_schedule(4) if i == iteration)
            for iteration in range(4)
        ]

        assert leaders == [CANDIDATE, BASELINE, CANDIDATE, BASELINE]

    def test_both_sides_lead_equally_over_an_even_count(self) -> None:
        leaders = [
            next(side for i, side in interleaved_schedule(10) if i == iteration)
            for iteration in range(10)
        ]

        assert leaders.count(CANDIDATE) == leaders.count(BASELINE)

    def test_zero_iterations_schedules_nothing(self) -> None:
        assert interleaved_schedule(0) == []
