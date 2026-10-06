"""Tests for `list_smith_bench.data.utils.fingerprint`.

`ab` leaves a micro untimed when its fingerprint matches on both sides, so a fingerprint that misses
a change would let a regression through unseen. These pin what moves it and what doesn't.
"""

from __future__ import annotations

from collections.abc import Callable
from pathlib import Path

from list_smith_bench.data.utils.fingerprint import depfile_inputs, micro_fingerprint

_ROOT = "/home/runner/work/list_smith/list_smith"
_COMMAND = ("compile", "exe", "Dart SDK version: 3.13.5")


def _depfile(root: str) -> str:
    return (
        f"{root}/benchmark/build/sync_search_scaling: "
        f"{root}/.dart_tool/package_config.json "
        f"{root}/benchmark/micro/sync_search_scaling.dart "
        f"{root}/lib/src/data/search/utils/sync_search_resolver.dart"
    )


def _contents(**overrides: bytes) -> dict[str, bytes]:
    return {
        "package_config.json": b'{"generated": "2026-10-06T11:49:39Z"}',
        "sync_search_scaling.dart": b"void main() {}",
        "sync_search_resolver.dart": b"resolveSyncSearch() {}",
        **overrides,
    }


def _reader(contents: dict[str, bytes]) -> Callable[[Path], bytes]:
    """Reads by file name, so the same files answer from any checkout."""
    return lambda path: contents[path.name]


class TestMicroFingerprint:
    def test_the_same_micro_in_another_checkout_keeps_its_fingerprint(self) -> None:
        """CI builds main in another folder, so a path in the hash would make every micro differ."""
        here = micro_fingerprint(_depfile(_ROOT), _reader(_contents()), _COMMAND)
        there = micro_fingerprint(
            _depfile("/home/runner/work/_temp/base"), _reader(_contents()), _COMMAND
        )

        assert here == there

    def test_a_changed_input_changes_it(self) -> None:
        before = micro_fingerprint(_depfile(_ROOT), _reader(_contents()), _COMMAND)
        after = micro_fingerprint(
            _depfile(_ROOT),
            _reader(
                _contents(**{"sync_search_resolver.dart": b"resolveSyncSearch() { slower(); }"})
            ),
            _COMMAND,
        )

        assert before != after

    def test_a_different_build_command_changes_it(self) -> None:
        """Another SDK or compile flag builds different code from the same sources."""
        before = micro_fingerprint(_depfile(_ROOT), _reader(_contents()), _COMMAND)
        after = micro_fingerprint(
            _depfile(_ROOT), _reader(_contents()), ("compile", "exe", "Dart SDK version: 3.14.0")
        )

        assert before != after

    def test_a_fresh_package_config_leaves_it(self) -> None:
        """`pub get` stamps the time into it, so counting it would time every micro."""
        before = micro_fingerprint(_depfile(_ROOT), _reader(_contents()), _COMMAND)
        after = micro_fingerprint(
            _depfile(_ROOT),
            _reader(_contents(**{"package_config.json": b'{"generated": "2026-10-07T08:00:00Z"}'})),
            _COMMAND,
        )

        assert before == after


class TestDepfileInputs:
    def test_an_escaped_space_stays_inside_its_path(self) -> None:
        inputs = depfile_inputs("build/micro: /my\\ checkout/a.dart /b.dart")

        assert inputs == [Path("/my checkout/a.dart"), Path("/b.dart")]
