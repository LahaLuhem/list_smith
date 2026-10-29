"""Tests for `list_smith_bench.subcommands.build`."""

from __future__ import annotations

import argparse
from pathlib import Path

import pytest

from list_smith_bench.data.utils.fingerprint import fingerprint_path
from list_smith_bench.subcommands import build


class TestPrune:
    def test_a_removed_micro_leaves_nothing_behind_for_run_to_time(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        micro_dir = tmp_path / "micro"
        micro_dir.mkdir()
        source = micro_dir / "kept.dart"
        source.touch()
        build_dir = tmp_path / "build"
        for name in ("kept", "removed"):
            fingerprint = fingerprint_path(build_dir, name)
            fingerprint.parent.mkdir(parents=True, exist_ok=True)
            fingerprint.touch()
            fingerprint.with_suffix(".d").touch()
            (build_dir / name).touch()
        monkeypatch.setattr(build, "BUILD_DIR", build_dir)
        monkeypatch.setattr(build, "PROJECT_ROOT", tmp_path)
        monkeypatch.setattr(build, "_SOURCE_ROOTS", [micro_dir])
        monkeypatch.setattr(build, "discover_sources", lambda: [source])

        build.cmd_build(argparse.Namespace(force=False, workers=0))

        built = sorted(
            path.relative_to(build_dir).as_posix()
            for path in build_dir.rglob("*")
            if path.is_file()
        )
        assert built == ["inputs/kept", "inputs/kept.d", "kept"]
