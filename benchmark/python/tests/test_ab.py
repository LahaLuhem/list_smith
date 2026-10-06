"""Tests for `list_smith_bench.subcommands.ab`'s pure parts: the run order and each side's command.

Both are what keeps the gate from favouring a side, so they are pinned here rather than left to a
read of the runner. Everything else in `ab` is subprocess plumbing.
"""

from __future__ import annotations

from pathlib import Path

from list_smith_bench.data.utils.fingerprint import fingerprint_path
from list_smith_bench.subcommands.ab import (
    BASELINE,
    CANDIDATE,
    interleaved_schedule,
    run_command,
    staged_exe,
    unchanged_micros,
)


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


class TestSideCommands:
    def test_both_sides_run_with_arguments_of_the_same_length(self, tmp_path: Path) -> None:
        """Equal lengths, so neither side's process starts with its memory laid out differently."""
        commands = {
            side: run_command(tmp_path, "sync_search_scaling", side, 3, ("abc1234", "2.0.0"), 500)
            for side in (CANDIDATE, BASELINE)
        }

        assert [len(arg) for arg in commands[CANDIDATE]] == [len(arg) for arg in commands[BASELINE]]

    def test_each_side_runs_its_own_copy(self, tmp_path: Path) -> None:
        """Sharing one copy would time a build against itself and pass whatever changed."""
        candidate_exe = staged_exe(tmp_path, "sync_search_scaling", CANDIDATE)
        baseline_exe = staged_exe(tmp_path, "sync_search_scaling", BASELINE)

        assert candidate_exe != baseline_exe


class TestUnchangedMicros:
    @staticmethod
    def _build(root: Path, fingerprints: dict[str, str]) -> Path:
        for name, fingerprint in fingerprints.items():
            path = fingerprint_path(root, name)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(fingerprint)

        return root

    def test_only_a_fingerprint_matching_on_both_sides_skips_the_timing(
        self, tmp_path: Path
    ) -> None:
        """A side without one, like a build from before fingerprints, still gets timed."""
        candidate = self._build(tmp_path / "candidate", {"same": "1", "changed": "2", "new": "3"})
        baseline = self._build(tmp_path / "baseline", {"same": "1", "changed": "9"})

        untimed = unchanged_micros(["same", "changed", "new", "neither"], candidate, baseline)

        assert untimed == {"same"}
