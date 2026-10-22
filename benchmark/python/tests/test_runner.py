"""Tests for `list_smith_bench.subcommands.runner`."""

from __future__ import annotations

import argparse
import subprocess
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path

import pytest

from list_smith_bench.subcommands import runner


class TestDesktopFlag:
    @pytest.mark.parametrize(
        ("device", "switches_flag"), [("macos", True), ("emulator-5554", False)]
    )
    def test_only_a_macos_run_switches_the_global_desktop_flag(
        self,
        device: str,
        switches_flag: bool,
        tmp_path: Path,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        entered: list[bool] = []

        @contextmanager
        def recording_flag() -> Iterator[None]:
            entered.append(True)
            yield

        monkeypatch.setattr(runner, "macos_desktop_enabled", recording_flag)
        monkeypatch.setattr(
            runner.subprocess, "run", lambda *_, **__: subprocess.CompletedProcess([], 0)
        )
        args = argparse.Namespace(scenarios=["bare_listview_test"], iterations=1, device=device)

        runner._run_scenarios(args, tmp_path, "sha", "0.0.0")

        assert bool(entered) == switches_flag
